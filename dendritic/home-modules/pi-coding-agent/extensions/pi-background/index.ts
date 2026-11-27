/**
 * bg_bash: start a shell command detached, poll it, cancel it.
 *
 * Each job writes its log and metadata under $TMPDIR/pi-background. A detached
 * child survives this process, so a later session can still read the log.
 */

import { spawn } from "node:child_process";
import { randomBytes } from "node:crypto";
import { existsSync, mkdirSync, readdirSync, readFileSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";

const STATE_DIR = join(process.env.TMPDIR ?? tmpdir(), "pi-background");
const TAIL_BYTES = 4000;

interface JobMeta {
  id: string;
  name: string;
  command: string;
  pid: number;
  startedAt: number;
  exitedAt: number | null;
  exitCode: number | null;
}

const TEXT = Type.Object({
  command: Type.Optional(Type.String({ description: "Shell command to run in the background" })),
  name: Type.Optional(Type.String({ description: "Short label for the job" })),
  action: Type.Optional(
    Type.Union([Type.Literal("start"), Type.Literal("status"), Type.Literal("list"), Type.Literal("cancel")], {
      description: "Defaults to start",
    }),
  ),
  job_id: Type.Optional(Type.String({ description: "Job id for status or cancel" })),
});

const logPath = (id: string) => join(STATE_DIR, `${id}.log`);
const metaPath = (id: string) => join(STATE_DIR, `${id}.json`);

function readMeta(id: string): JobMeta | undefined {
  try {
    return JSON.parse(readFileSync(metaPath(id), "utf8")) as JobMeta;
  } catch {
    return undefined;
  }
}

function allMeta(): JobMeta[] {
  if (!existsSync(STATE_DIR)) return [];
  const out: JobMeta[] = [];
  for (const file of readdirSync(STATE_DIR)) {
    if (!file.endsWith(".json")) continue;
    try {
      out.push(JSON.parse(readFileSync(join(STATE_DIR, file), "utf8")) as JobMeta);
    } catch {
      // Skip a torn write.
    }
  }
  return out.sort((a, b) => b.startedAt - a.startedAt);
}

function isAlive(pid: number): boolean {
  try {
    process.kill(pid, 0);
    return true;
  } catch {
    return false;
  }
}

function tail(id: string): string {
  const path = logPath(id);
  if (!existsSync(path)) return "";
  const text = readFileSync(path, "utf8");
  return text.length <= TAIL_BYTES ? text : text.slice(-TAIL_BYTES);
}

function refresh(meta: JobMeta): JobMeta {
  if (meta.exitedAt !== null || isAlive(meta.pid)) return meta;
  const next: JobMeta = { ...meta, exitedAt: Date.now(), exitCode: null };
  writeFileSync(metaPath(next.id), JSON.stringify(next));
  return next;
}

function text(s: string) {
  return { content: [{ type: "text" as const, text: s }], details: {} };
}

function start(command: string, name: string) {
  mkdirSync(STATE_DIR, { recursive: true });
  const id = randomBytes(6).toString("hex");
  const child = spawn("sh", ["-c", `exec >${logPath(id)} 2>&1; ${command}`], {
    detached: true,
    stdio: "ignore",
  });
  const meta: JobMeta = {
    id,
    name: name || command.slice(0, 40),
    command,
    pid: child.pid ?? 0,
    startedAt: Date.now(),
    exitedAt: null,
    exitCode: null,
  };
  writeFileSync(metaPath(id), JSON.stringify(meta));
  child.unref();
  return text(`started ${id} name=${meta.name} pid=${meta.pid} log=${logPath(id)}`);
}

function status(jobId?: string) {
  if (!jobId) return text("job_id is required with status.");
  const meta = readMeta(jobId);
  if (!meta) return text(`no job ${jobId}`);
  const live = refresh(meta);
  const state = live.exitedAt === null ? "running" : "exited";
  return text(`[${state}] ${live.id} name=${live.name} pid=${live.pid}\n${tail(live.id)}`);
}

function cancel(jobId?: string) {
  if (!jobId) return text("job_id is required with cancel.");
  const meta = readMeta(jobId);
  if (!meta) return text(`no job ${jobId}`);
  if (meta.exitedAt !== null) return text(`job ${jobId} already exited`);
  try {
    process.kill(meta.pid, "SIGTERM");
  } catch {
    return text(`job ${jobId} is gone`);
  }
  const next: JobMeta = { ...meta, exitedAt: Date.now(), exitCode: null };
  writeFileSync(metaPath(next.id), JSON.stringify(next));
  return text(`cancelled ${jobId}`);
}

function list() {
  const jobs = allMeta().slice(0, 20);
  if (jobs.length === 0) return text("no jobs");
  const rows = jobs.map((j) => {
    const live = refresh(j);
    const state = live.exitedAt === null ? "running" : "exited";
    return `${state}  ${live.id}  ${live.name}`;
  });
  return text(rows.join("\n"));
}

export default function (pi: ExtensionAPI) {
  pi.registerTool({
    name: "bg_bash",
    label: "bg_bash",
    description:
      "Run a shell command detached, then poll or cancel it. action=start needs command; status and cancel need job_id.",
    parameters: TEXT,
    async execute(_toolCallId, params) {
      const action = params.action ?? "start";
      if (action === "start") {
        if (!params.command) return text("command is required with start.");
        return start(params.command, params.name ?? "");
      }
      if (action === "status") return status(params.job_id);
      if (action === "cancel") return cancel(params.job_id);
      return list();
    },
  });
}
