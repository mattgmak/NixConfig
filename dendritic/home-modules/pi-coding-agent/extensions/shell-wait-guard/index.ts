import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

// A foreground wait wastes the turn. The ctx_bg tool ends the turn at once, and
// the harness wakes the agent when the job finishes. So no caller needs sleep.
const GUARDED_TOOLS = new Set(["ctx_shell", "bash"]);
// A duration follows a real call, so `rg sleep src/` never matches.
const SLEEP_CALL = /(?:^|[\s;&|()`$])(?:[\w./-]*\/)?(?:usleep|sleep)\s+(?:\d|\$\w)/;

const REASON =
	"Blocked: a foreground sleep holds the turn open and ages the prompt cache. "
	+ "Run the work with ctx_bg, then end the turn. The harness wakes you with the result. "
	+ "For a command that must wait until a condition ends, use a blocking form: "
	+ "`gh run watch`, `tail -f --pid=<pid>`, or a plain foreground command.";

function callsSleep(command: string): boolean {
	return SLEEP_CALL.test(command);
}

export default function (pi: ExtensionAPI): void {
	pi.on("tool_call", (event) => {
		if (!GUARDED_TOOLS.has(event.toolName)) return undefined;
		const command = (event.input as { command?: unknown } | undefined)?.command;
		if (typeof command !== "string") return undefined;
		if (!callsSleep(command)) return undefined;
		return { block: true, reason: REASON };
	});
}
