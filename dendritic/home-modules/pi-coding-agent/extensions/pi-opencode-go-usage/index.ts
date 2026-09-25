import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { truncateToWidth } from "@earendil-works/pi-tui";
import {
	formatOpenCodeGoUsage,
	getOpenCodeGoUsage,
	resolveOpenCodeGoApiKey,
	type OpenCodeGoUsage,
} from "./src/usage.ts";
import { redactSecrets } from "./src/security.ts";

const USAGE_WIDGET_KEY = "opencode-go-usage";

function createUsageWidget(usage: OpenCodeGoUsage) {
	return {
		render(width: number): string[] {
			const safeWidth = Number.isFinite(width) && width > 0 ? width : 1;
			return formatOpenCodeGoUsage(usage, Date.now(), safeWidth)
				.split("\n")
				.map((line) => truncateToWidth(line, safeWidth));
		},
		invalidate() {},
	};
}

export default function piOpenCodeGoUsageExtension(pi: ExtensionAPI): void {
	pi.registerCommand("opencode-go-usage", {
		description: "Show OpenCode Go subscription usage windows",
		handler: async (_args, ctx) => {
			const hasWidget = ctx.hasUI && typeof ctx.ui.setWidget === "function";
			if (hasWidget) {
				ctx.ui.setWidget(USAGE_WIDGET_KEY, undefined);
			}
			try {
				const apiKey = await resolveOpenCodeGoApiKey(ctx.modelRegistry);
				const usage = await getOpenCodeGoUsage(apiKey, ctx.sessionManager.getSessionId());
				const text = formatOpenCodeGoUsage(usage);
				if (ctx.hasUI) {
					if (hasWidget) {
						ctx.ui.setWidget(USAGE_WIDGET_KEY, () => createUsageWidget(usage));
					} else {
						ctx.ui.notify(text, "info");
					}
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
