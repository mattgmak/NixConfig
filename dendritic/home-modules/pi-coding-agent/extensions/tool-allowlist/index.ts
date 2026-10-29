import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

// Three roles: BLOCKED_TOOLS + BLOCKED_PATTERNS deny, REVIEWED_TOOLS records a
// deliberate active tool, and a name in neither stays active but gets reported.
const BLOCKED_TOOLS: readonly string[] = [
	"read",
	"bash",
	"powershell",
	"grep",
	"find",
	"ls",
	"tool_search",
	"say",
	"ctx_tree",
	"ctx_glob",
	"ctx_callgraph",
	"ctx_session",
	"ctx_call",
	"lean_ctx",
	"ctx_edit",
	"agent_browser_action",
	"agent_browser_qa",
	"agent_browser_electron",
	"agent_browser_source",
	"agent_browser_network_source",
	"codegraph_callees",
	"codegraph_status",
	"codegraph_files",
	"cursor",
	"cursor_ask_question",
	"cursor_activate_skill",
	"mem_save_prompt",
	"mem_session_finalize",
	"mem_session_start",
	"mem_session_end",
	"mem_current_project",
	"mem_doctor",
	"mem_capture_passive",
	"mem_review",
	"mem_judge",
	"mem_judge_many",
	"mem_compare",
	"mem_list_projects",
	"mem_pin",
	"mem_unpin",
	"read_parent_session",
	"read_session_file",
	"list_session_files",
	"list_subagent_sessions",
	"mcpScript",
];

const BLOCKED_PATTERNS: readonly string[] = ["mcp__*", "Linear_*", "github-readonly_*", "github_readonly_*", "argent_*", "nixos_*"];

const REVIEWED_TOOLS: readonly string[] = [
	"codemode",
	"edit",
	"write",
	"ctx_read",
	"ctx_shell",
	"ctx_bg",
	"ctx_compose",
	"ctx_search",
	"ctx_find",
	"ctx_grep",
	"ctx_patch",
	"ctx_ls",
	"ctx_expand",
	"todo",
	"ask_user_question",
	"read_session",
	"recall",
	"preview_export",
	"subagent",
	"subagents_list",
	"subagent_message",
	"subagent_stop",
	"codegraph_search",
	"codegraph_explore",
	"codegraph_node",
	"codegraph_callers",
	"codegraph_impact",
	"web_search",
	"fetch_content",
	"source_check",
	"get_search_content",
	"web_enable",
	"agent_browser",
	"agent_browser_code",
	"agent_browser_tools",
	"mcp",
	"mem_save",
	"mem_search",
	"mem_session_summary",
	"mem_context",
	"mem_get_observation",
	"mem_update",
	"mem_consolidate",
	"mem_suggest_topic_key",
	"ste_lint",
	"set_session_name",
	"get_session_name",
];

const GLOB_CHARS = /[*?[]/;
const REGEX_SPECIAL = new Set(["\\", "^", "$", ".", "+", "(", ")", "|", "{", "}", "]", "/"]);

function isPattern(entry: string): boolean {
	return GLOB_CHARS.test(entry);
}

// "*" and "?" are glob wildcards here, so they translate instead of escape.
function compile(pattern: string): RegExp {
	let source = "^";
	for (const char of pattern) {
		if (char === "*") source += ".*";
		else if (char === "?") source += ".";
		else if (REGEX_SPECIAL.has(char)) source += `\\${char}`;
		else source += char;
	}
	return new RegExp(`${source}$`);
}

const BLOCKED_MATCHERS: readonly RegExp[] = BLOCKED_PATTERNS.filter(isPattern).map(compile);

function isBlocked(name: string): boolean {
	return BLOCKED_TOOLS.includes(name) || BLOCKED_MATCHERS.some((matcher) => matcher.test(name));
}

function supportsDynamicTools(pi: ExtensionAPI): boolean {
	if (typeof pi.getAllTools !== "function" || typeof pi.getActiveTools !== "function" || typeof pi.setActiveTools !== "function") return false;
	const unsubscribe: unknown = pi.on("session_start", () => {});
	if (typeof unsubscribe !== "function") return false;
	unsubscribe();
	return true;
}

export default function (pi: ExtensionAPI): void {
	if (!supportsDynamicTools(pi)) {
		console.warn("[tool-allowlist] Dynamic tool activation requires Pi 0.86.0 or newer; denylist skipped.");
		return;
	}

	let logged = false;
	function reapplyDenylist(): void {
		const registered = pi.getAllTools().map((tool) => tool.name);
		const next = registered.filter((name) => !isBlocked(name));
		try {
			pi.setActiveTools(next);
		} catch (error) {
			console.warn(`[tool-allowlist] setActiveTools failed: ${error instanceof Error ? error.message : String(error)}`);
			return;
		}
		if (!logged) {
			logged = true;
			const reviewed = new Set(REVIEWED_TOOLS);
			const unknown = registered.filter((name) => !isBlocked(name) && !reviewed.has(name));
			if (unknown.length > 0) console.debug(`[tool-allowlist] unknown: ${unknown.join(", ")}`);
		}
	}

	pi.on("session_start", () => reapplyDenylist());
	pi.on("session_tree", () => reapplyDenylist());
	pi.on("mcp_servers_change", () => reapplyDenylist());
	pi.on("before_agent_start", () => reapplyDenylist());
}
