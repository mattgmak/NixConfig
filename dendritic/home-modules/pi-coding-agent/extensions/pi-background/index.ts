/**
 * bg_bash: start a shell command detached, poll it, cancel it.
 *
 * Each job writes its log and metadata under $TMPDIR/pi-background. A detached
 * child survives this process, so a later session can still read the log. The
 * TUI widget shows running jobs. An exit sends a wake message that starts a turn.
 */

import { spawn } from "node:child_process";
import { randomBytes } from "node:crypto";
import { existsSync, mkdirSync, readdirSync, readFileSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import type { ExtensionAPI, ExtensionContext, ThemeColor } from "@earendil-works/pi-coding-agent";
import { Box, Text } from "@earendil-works/pi-tui";
import { Type } from "typebox";

const STATE_DIR = join(process.env.TMPDIR ?? tmpdir(), "pi-background");
const TAIL_BYTES = 4000;
const WIDGET_KEY = "pi-background-jobs";
const TICK_MS = 1000;
const MAX_ROWS = 3;
const CUSTOM_TYPE = "pi-background-job";
const EXIT_LINE = /\n?exit=(\d+)\s*$/;

const ICON = {
  done: "\uF00D",
  fail: "\uF00D",
  stopped: "\uF05E",
  running: "\uF110",
  clock: "\uF017",
  id: "\uF292",
};
const BAR = "\u2503 ";
const ELAPSED_COL = 7;
const TAIL_MAX = 60;

type Outcome = "success" | "failure" | "cancelled" | "running";
const GLYPH: Record<Outcome, { color: ThemeColor; mark: string; label: string }> = {
  success: { color: "success", mark: ICON.done, label: "completed" },
  failure: { color: "error", mark: ICON.fail, label: "failed" },
  cancelled: { color: "warning", mark: ICON.stopped, label: "cancelled" },
  running: { color: "warning", mark: ICON.running, label: "running" },
};

interface JobMeta {
  id: string;
  name: string;
  command: string;
  pid: number;
  startedAt: number;
  exitedAt: number | null;
  exitCode: number | null;
  woken?: boolean;
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

function writeMeta(meta: JobMeta): void {
  writeFileSync(metaPath(meta.id), JSON.stringify(meta));
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

function stripExit(text: string): string {
  return text.replace(EXIT_LINE, "").replace(/^\s*\r?\n/, "");
}

function refresh(meta: JobMeta): JobMeta {
  if (meta.exitedAt !== null || isAlive(meta.pid)) return meta;
  const match = EXIT_LINE.exec(tail(meta.id));
  const next: JobMeta = { ...meta, exitedAt: Date.now(), exitCode: match ? Number(match[1]) : null };
  writeMeta(next);
  return next;
}

function text(s: string) {
  return { content: [{ type: "text" as const, text: s }], details: {} };
}

// --- TUI state ---

let ctxRef: ExtensionContext | undefined;
let ticker: ReturnType<typeof setInterval> | undefined;
const widgetState = {
  theme: undefined as any,
};

function durationText(startedAt: number): string {
  const seconds = Math.max(0, Math.floor((Date.now() - startedAt) / 1000));
  if (seconds < 60) return `${seconds}s`;
  const minutes = Math.floor(seconds / 60);
  if (minutes < 60) return `${minutes}m`;
  return `${Math.floor(minutes / 60)}h ${minutes % 60}m`;
}

function lastMeaningfulLine(text: string): string {
  const lines = stripExit(text).split(/\r?\n/);
  for (let i = lines.length - 1; i >= 0; i--) {
    const line = lines[i].trim();
    if (line) return line;
  }
  return "";
}

function field(theme: any, glyph: string, color: ThemeColor, value: string): string {
  return `${theme.fg(color, glyph)} ${theme.fg("dim", value)}`;
}

function widgetRow(theme: any, name: string, meta: JobMeta, line: string): string {
  const outcome: Outcome =
    meta.exitedAt === null ? "running" : meta.exitCode === 0 ? "success" : meta.exitCode === null ? "cancelled" : "failure";
  const glyph = GLYPH[outcome];
  const elapsed = durationText(meta.startedAt).padStart(ELAPSED_COL);
  const fields = [
    theme.fg("accent", name),
    field(theme, ICON.clock, "dim", elapsed),
    field(theme, glyph.mark, glyph.color, glyph.label),
    field(theme, ICON.id, "dim", meta.id),
  ];
  const detail = line ? line.slice(0, TAIL_MAX) : `pid ${meta.pid}`;
  return BAR + fields.join("  ") + "  " + theme.fg("muted", detail);
}

function setUi(ctx: ExtensionContext): void {
  ctxRef = ctx;
  if (ctx.mode !== "tui") return;
  try {
    widgetState.theme = ctx.ui.theme;
    updateWidget([]);
  } catch (error) {
    ctx.ui.notify(`pi-background setUi: ${error instanceof Error ? error.message : String(error)}`, "error");
  }
}

function updateWidget(running: JobMeta[]): void {
  const ctx = ctxRef;
  const theme = widgetState.theme;
  if (!ctx || !theme) return;
  if (running.length === 0) {
    ctx.ui.setWidget(WIDGET_KEY, undefined);
    return;
  }
  const shown = running.slice(0, MAX_ROWS);
  const overflow = Math.max(0, running.length - MAX_ROWS);
  const lines = shown.map((meta) => widgetRow(theme, meta.name || meta.id, meta, lastMeaningfulLine(tail(meta.id))));
  if (overflow > 0) lines.push(BAR + theme.fg("muted", `+${overflow} more`));
  ctx.ui.setWidget(WIDGET_KEY, lines, { placement: "aboveEditor" });
}

function wake(meta: JobMeta): void {
  const ctx = ctxRef;
  if (!ctx || meta.woken) return;
  meta.woken = true;
  writeMeta(meta);
  const exit = meta.exitCode === null ? "unknown" : String(meta.exitCode);
  const body = stripExit(tail(meta.id));
  const content = [
    `bg_bash job ${meta.id} finished with exit code ${exit}.`,
    "",
    `$ ${meta.command}`,
    "",
    body || "(no output)",
  ].join("\n");
  void piSendMessage({
    customType: CUSTOM_TYPE,
    content,
    display: true,
    details: { jobId: meta.id, name: meta.name, command: meta.command, exitCode: meta.exitCode },
  }, { triggerTurn: true, deliverAs: "followUp" });
}

let piSendMessage: ExtensionAPI["sendMessage"] = () => Promise.resolve();

function tick(): void {
  const running: JobMeta[] = [];
  for (const job of allMeta()) {
    const live = refresh(job);
    if (live.exitedAt === null) {
      running.push(live);
      continue;
    }
    if (!live.woken) wake(live);
  }
  updateWidget(running);
}

function ensureTicker(): void {
  if (ticker || !ctxRef || ctxRef.mode !== "tui" || !widgetState.theme) return;
  ticker = setInterval(tick, TICK_MS);
  tick();
}

// --- Tool actions ---

function start(command: string, name: string) {
  mkdirSync(STATE_DIR, { recursive: true });
  const id = randomBytes(6).toString("hex");
  const child = spawn("sh", ["-c", `exec >${logPath(id)} 2>&1; { ${command}; }; printf 'exit=%s\\n' "$?" >>${logPath(id)}`], {
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
  writeMeta(meta);
  child.unref();
  ensureTicker();
  return text(`started ${id} name=${meta.name} pid=${meta.pid} log=${logPath(id)}`);
}

function status(jobId?: string) {
  if (!jobId) return text("job_id is required with status.");
  const meta = readMeta(jobId);
  if (!meta) return text(`no job ${jobId}`);
  const live = refresh(meta);
  const state = live.exitedAt === null ? "running" : `exited code=${live.exitCode ?? "unknown"}`;
  return text(`[${state}] ${live.id} name=${live.name} pid=${live.pid}\n${stripExit(tail(live.id))}`);
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
  writeMeta(next);
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
  piSendMessage = pi.sendMessage.bind(pi);

  pi.registerMessageRenderer(CUSTOM_TYPE, (message, theme, context) => {
    const details = (message.details ?? {}) as { name?: string; command?: string; exitCode?: number | null };
    const label = details.name || "job";
    const code = details.exitCode ?? "?";
    const color: ThemeColor = details.exitCode === 0 ? "success" : details.exitCode === null ? "warning" : "error";
    const command = details.command ? `  $ ${details.command.slice(0, 72)}` : "";
    const body = stripExit(typeof message.content === "string" ? message.content : "").slice(0, 2000);
    const box = new Box(() => theme.bg("customMessageBg", ""), () => {
      const lines = [
        new Text(`${theme.fg(color, `bg_bash ${label}`)} ${theme.fg("dim", `exit ${code}`)}`, 0, false),
      ];
      if (command) lines.push(new Text(theme.fg("dim", command), 0, false));
      if (body) lines.push(new Text(theme.fg("muted", body), 0, true));
      return lines;
    });
    void context;
    return box;
  });

  pi.on("session_start", async (_event, ctx) => {
    setUi(ctx);
    ensureTicker();
  });

  pi.on("session_shutdown", () => {
    if (ticker) {
      clearInterval(ticker);
      ticker = undefined;
    }
    ctxRef?.ui.setWidget(WIDGET_KEY, undefined);
    widgetState.theme = undefined;
    ctxRef = undefined;
  });

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
