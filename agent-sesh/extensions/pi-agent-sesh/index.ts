import type {
	ExtensionAPI,
	ExtensionContext,
} from "@earendil-works/pi-coding-agent";
import { execFile } from "node:child_process";
import { mkdir, readFile, writeFile } from "node:fs/promises";
import { homedir } from "node:os";
import { basename, dirname, join } from "node:path";
import { promisify } from "node:util";

const execFileAsync = promisify(execFile);

export type AgentSeshStatus = "idle" | "working" | "tool_call" | "waiting";

export interface AgentSeshSession {
	id: string;
	tmux_target: string;
	cwd: string;
	branch?: string;
	title: string;
	status: AgentSeshStatus;
	tool_name?: string;
	model?: string;
	agent: "pi";
	updated_at: string;
}

interface RegistryFile {
	version: 1;
	sessions: AgentSeshSession[];
}

interface ToolExecutionStartEvent {
	toolName?: string;
}

interface BeforeAgentStartEvent {
	prompt?: string;
}

function registryPath(): string {
	const stateHome =
		process.env.XDG_STATE_HOME ?? join(homedir(), ".local", "state");
	return join(stateHome, "agent-sesh", "sessions.json");
}

async function readRegistry(): Promise<RegistryFile> {
	try {
		const raw = await readFile(registryPath(), "utf8");
		return JSON.parse(raw) as RegistryFile;
	} catch {
		return { version: 1, sessions: [] };
	}
}

async function writeRegistry(file: RegistryFile): Promise<void> {
	const path = registryPath();
	await mkdir(dirname(path), { recursive: true });
	await writeFile(path, `${JSON.stringify(file, null, 2)}\n`, "utf8");
}

async function tmuxTarget(): Promise<string | null> {
	if (!process.env.TMUX) {
		return null;
	}
	try {
		const { stdout } = await execFileAsync("tmux", [
			"display-message",
			"-p",
			"#{pane_id}",
		]);
		return stdout.trim() || null;
	} catch {
		return null;
	}
}

async function gitBranch(cwd: string): Promise<string | undefined> {
	try {
		const { stdout } = await execFileAsync("git", [
			"-C",
			cwd,
			"rev-parse",
			"--abbrev-ref",
			"HEAD",
		]);
		const branch = stdout.trim();
		return branch || undefined;
	} catch {
		return undefined;
	}
}

function modelLabel(ctx: ExtensionContext): string | undefined {
	const model = ctx.model;
	if (!model) {
		return undefined;
	}
	if (model.name) {
		return model.name;
	}
	if (model.provider && model.id) {
		return `${model.provider}/${model.id}`;
	}
	return model.id;
}

function sessionTitle(
	pi: ExtensionAPI,
	ctx: ExtensionContext,
	prompt?: string,
): string {
	const named = pi.getSessionName?.();
	if (named && named.trim().length > 0) {
		return named.trim();
	}
	const trimmedPrompt = prompt?.trim();
	if (trimmedPrompt) {
		return trimmedPrompt.length > 80
			? `${trimmedPrompt.slice(0, 77)}...`
			: trimmedPrompt;
	}
	return basename(ctx.sessionManager.getCwd());
}

function truncateToolName(toolName: string): string {
	return toolName.length > 64 ? `${toolName.slice(0, 61)}...` : toolName;
}

export async function upsertSession(partial: {
	id: string;
	cwd: string;
	title: string;
	status?: AgentSeshStatus;
	tool_name?: string;
	model?: string;
}): Promise<void> {
	const target = await tmuxTarget();
	if (!target) {
		return;
	}

	const branch = await gitBranch(partial.cwd);
	const file = await readRegistry();
	const now = new Date().toISOString();
	const existing = file.sessions.find((session) => session.id === partial.id);
	const next: AgentSeshSession = {
		id: partial.id,
		tmux_target: target,
		cwd: partial.cwd,
		branch,
		title: partial.title,
		status: partial.status ?? existing?.status ?? "idle",
		tool_name: partial.tool_name ?? existing?.tool_name,
		model: partial.model ?? existing?.model,
		agent: "pi",
		updated_at: now,
	};

	file.sessions = [
		next,
		...file.sessions.filter((session) => session.id !== partial.id),
	];
	await writeRegistry(file);
}

export async function removeSession(id: string): Promise<void> {
	const file = await readRegistry();
	file.sessions = file.sessions.filter((session) => session.id !== id);
	await writeRegistry(file);
}

export async function setStatus(
	id: string,
	status: AgentSeshStatus,
	toolName?: string,
): Promise<void> {
	const file = await readRegistry();
	const session = file.sessions.find((entry) => entry.id === id);
	if (!session) {
		return;
	}
	session.status = status;
	session.tool_name = toolName;
	session.updated_at = new Date().toISOString();
	await writeRegistry(file);
}

export default function piAgentSeshExtension(pi: ExtensionAPI): void {
	let sessionId: string | undefined;
	let lastTitle = "pi session";

	function requireSessionId(ctx: ExtensionContext): string | undefined {
		return sessionId ?? ctx.sessionManager.getSessionId();
	}

	pi.on("session_start", async (_event, ctx) => {
		sessionId = ctx.sessionManager.getSessionId();
		if (!sessionId) {
			return;
		}
		lastTitle = sessionTitle(pi, ctx);
		await upsertSession({
			id: sessionId,
			cwd: ctx.sessionManager.getCwd(),
			title: lastTitle,
			model: modelLabel(ctx),
			status: "idle",
		});
	});

	pi.on("before_agent_start", async (event: BeforeAgentStartEvent, ctx) => {
		const id = requireSessionId(ctx);
		if (!id) {
			return;
		}
		lastTitle = sessionTitle(pi, ctx, event.prompt);
		await upsertSession({
			id,
			cwd: ctx.sessionManager.getCwd(),
			title: lastTitle,
			model: modelLabel(ctx),
			status: "working",
		});
	});

	pi.on("tool_execution_start", async (event: ToolExecutionStartEvent, ctx) => {
		const id = requireSessionId(ctx);
		if (!id || !event.toolName) {
			return;
		}
		await setStatus(id, "tool_call", truncateToolName(event.toolName));
	});

	pi.on("agent_end", async (_event, ctx) => {
		const id = requireSessionId(ctx);
		if (!id) {
			return;
		}
		await upsertSession({
			id,
			cwd: ctx.sessionManager.getCwd(),
			title: lastTitle,
			model: modelLabel(ctx),
			status: "waiting",
		});
	});

	pi.on("session_shutdown", async (_event, ctx) => {
		const id = requireSessionId(ctx);
		if (!id) {
			return;
		}
		await removeSession(id);
		sessionId = undefined;
	});
}
