import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import {
	formatOpenCodeGoUsage,
	getOpenCodeGoUsage,
	resolveOpenCodeGoApiKey,
} from "./src/usage.ts";
import { redactSecrets } from "./src/security.ts";

export default function piOpenCodeGoUsageExtension(pi: ExtensionAPI): void {
	pi.registerCommand("opencode-go-usage", {
		description: "Show OpenCode Go subscription usage windows",
		handler: async (_args, ctx) => {
			try {
				const apiKey = await resolveOpenCodeGoApiKey(ctx.modelRegistry);
				const usage = await getOpenCodeGoUsage(apiKey, ctx.sessionManager.getSessionId());
				const text = formatOpenCodeGoUsage(usage);
				if (ctx.hasUI) {
					ctx.ui.notify(text, "info");
				} else {
					console.log(text);
				}
			} catch (error) {
				const text = `OpenCode Go usage unavailable: ${redactSecrets(
					error instanceof Error ? error.message : String(error),
				)}`;
				if (ctx.hasUI) {
					ctx.ui.notify(text, "error");
				} else {
					console.error(text);
				}
			}
		},
	});
}
