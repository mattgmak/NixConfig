import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { formatClinePassUsage, getClinePassUsage, resolveClinePassApiKey } from "./src/usage.ts";
import { redactSecrets } from "./src/security.ts";

export default function piClinePassUsageExtension(pi: ExtensionAPI): void {
	pi.registerCommand("clinepass-usage", {
		description: "Show ClinePass subscription usage windows",
		handler: async (_args, ctx) => {
			try {
				const apiKey = await resolveClinePassApiKey(ctx.modelRegistry);
				const usage = await getClinePassUsage(apiKey);
				const text = formatClinePassUsage(usage);
				if (ctx.hasUI) {
					ctx.ui.notify(text, "info");
				} else {
					console.log(text);
				}
			} catch (error) {
				const text = `ClinePass usage unavailable: ${redactSecrets(
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
