import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { formatCursorUsage, getCursorUsageSummary } from "./src/usage.ts";
import { redactSecrets } from "./src/security.ts";

export default function piCursorUsageExtension(pi: ExtensionAPI): void {
	pi.registerCommand("cursor-usage", {
		description: "Show Cursor subscription plan quota and on-demand spend",
		handler: async (_args, ctx) => {
			try {
				const text = formatCursorUsage(await getCursorUsageSummary());
				if (ctx.hasUI) {
					ctx.ui.notify(text, "info");
				} else {
					console.log(text);
				}
			} catch (error) {
				const text = `Cursor usage unavailable: ${redactSecrets(
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
