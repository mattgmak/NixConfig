import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import subagentsDefault, {
	registerToolExtension,
} from "../vendor/mattgmak/pi-interactive-subagents/pi-extension/subagents/index.ts";

const loaderDir = dirname(fileURLToPath(import.meta.url));
const webAccessPath = join(loaderDir, "pi-web-access/index.ts");

registerToolExtension("web_search", webAccessPath);
registerToolExtension("fetch_content", webAccessPath);

export default subagentsDefault;
