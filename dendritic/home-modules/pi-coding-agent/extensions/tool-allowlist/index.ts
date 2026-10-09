import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const ALLOWED_TOOLS: readonly string[] = [
	"codemode",
	"edit",
	"write",
	"ctx_read",
	"ctx_shell",
	"ctx_compose",
	"ctx_search",
	"todo",
	"recall",
	"subagent",
	"subagents_list",
	"subagent_message",
	"web_search",
	"mcp",
	"codegraph_search",
	"mem_save",
	"mem_search",
	"mem_session_summary",
	"get_search_content",
	"fetch_content",
	"source_check",
	"nix",
	"nix_versions",
	"codegraph_explore",
	"codegraph_node",
	"codegraph_callers",
	"codegraph_impact",
	"mem_context",
	"mem_get_observation",
	"agent_browser",
	"agent_browser_code",
	"agent_browser_tools",
	"ctx_find",
	"ctx_grep",
	"ctx_patch",
	"read_session",
	"preview_export",
];

function supportsDynamicTools(pi: ExtensionAPI): boolean {
	if (typeof pi.getAllTools !== "function" || typeof pi.getActiveTools !== "function" || typeof pi.setActiveTools !== "function") return false;
	const unsubscribe: unknown = pi.on("session_start", () => {});
	if (typeof unsubscribe !== "function") return false;
	unsubscribe();
	return true;
}

export default function (pi: ExtensionAPI): void {
	if (!supportsDynamicTools(pi)) {
		console.warn("[tool-allowlist] Dynamic tool activation requires Pi 0.86.0 or newer; allowlist skipped.");
		return;
	}

	let logged = false;
	function reapplyAllowlist(): void {
		const registered = new Set(pi.getAllTools().map((tool) => tool.name));
		const next = ALLOWED_TOOLS.filter((name) => registered.has(name));
		try {
			pi.setActiveTools(next);
		} catch (error) {
			console.warn(`[tool-allowlist] setActiveTools failed: ${error instanceof Error ? error.message : String(error)}`);
			return;
		}
		if (!logged) {
			logged = true;
			console.debug(`[tool-allowlist] active: ${next.join(", ")}`);
		}
	}

	pi.on("session_start", () => reapplyAllowlist());
	pi.on("session_tree", () => reapplyAllowlist());
	pi.on("mcp_servers_change", () => reapplyAllowlist());
	pi.on("before_agent_start", () => reapplyAllowlist());
}
