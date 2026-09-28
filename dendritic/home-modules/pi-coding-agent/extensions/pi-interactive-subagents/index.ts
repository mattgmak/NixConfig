import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import subagentsDefault, {
	registerToolExtension,
} from "../vendor/mattgmak/pi-interactive-subagents/pi-extension/subagents/index.ts";

const loaderDir = dirname(fileURLToPath(import.meta.url));
const webAccessPath = join(loaderDir, "pi-web-access/index.ts");
// Sibling extension dir — the loader lives in extensions/pi-interactive-subagents/,
// so the adapter is one level up, not inside this folder.
const mcpAdapterPath = join(loaderDir, "..", "pi-mcp-adapter", "index.ts");

registerToolExtension("web_search", webAccessPath);
registerToolExtension("fetch_content", webAccessPath);

// MCP tools are extension-backed: without a registration a restricted subagent
// that names them in `tools:` resolves nothing, and `--no-extensions` leaves it
// with only `ask_question`. Registering the names lets such a sandbox load the
// adapter back via `-e`, e.g. `tools: …, mcp, mcp__argent`.
registerToolExtension("mcp", mcpAdapterPath);
registerToolExtension("mcp__argent", mcpAdapterPath);

export default subagentsDefault;
