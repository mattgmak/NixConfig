import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

// A foreground wait wastes the turn. The ctx_bg tool ends the turn at once, and
// the harness wakes the agent when the job finishes. So no caller needs sleep.
const GUARDED_TOOLS = new Set(["ctx_shell", "bash"]);
// A short settle sleep inside a sequence costs nothing: `tap; sleep 1; dump`.
// Only a wait of 3 s or more holds the turn open, so only that one blocks.
const SLEEP_CALL =
	/(?:^|[\s;&|()`$])(?:[\w./-]*\/)?(?:sleep\s+(\d+(?:\.\d+)?)|usleep\s+(\d+))/g;
const MIN_WAIT_SECONDS = 3;

const REASON =
	"Blocked: a foreground sleep holds the turn open and ages the prompt cache. "
	+ "Run the work with ctx_bg, then end the turn. The harness wakes you with the result. "
	+ "For a command that must wait until a condition ends, use a blocking form: "
	+ "`gh run watch`, `tail -f --pid=<pid>`, or a plain foreground command.";

function callsLongWait(command: string): boolean {
	for (const match of command.matchAll(SLEEP_CALL)) {
		const seconds = match[1] === undefined ? Number(match[2]) / 1e6 : Number(match[1]);
		if (seconds >= MIN_WAIT_SECONDS) return true;
	}
	return false;
}

export default function (pi: ExtensionAPI): void {
	pi.on("tool_call", (event) => {
		if (!GUARDED_TOOLS.has(event.toolName)) return undefined;
		const command = (event.input as { command?: unknown } | undefined)?.command;
		if (typeof command !== "string") return undefined;
		if (!callsLongWait(command)) return undefined;
		return { block: true, reason: REASON };
	});
}
