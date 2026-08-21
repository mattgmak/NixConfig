import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { getStartupCursorAccessToken } from "../vendor/Rahularya01/pi-cursor/src/extension/auth.ts";
import {
	formatCursorUsage,
	getCursorUsageSummary,
} from "../vendor/Rahularya01/pi-cursor/src/usage.ts";
import { redactSecrets } from "../vendor/Rahularya01/pi-cursor/src/utils/security.ts";

async function getAccessToken(): Promise<string> {
	const resolved = await getStartupCursorAccessToken();
	if (!resolved?.accessToken) {
		throw new Error(
			"Not logged in to Cursor. Run /login cursor, log in via Cursor CLI, or set CURSOR_USAGE_SESSION_TOKEN.",
		);
	}
	return resolved.accessToken;
}

export default function piCursorUsageExtension(pi: ExtensionAPI): void {
	pi.registerCommand("cursor-usage", {
		description: "Show Cursor subscription plan quota and on-demand spend",
		handler: async (_args, ctx) => {
			try {
				const text = formatCursorUsage(await getCursorUsageSummary(getAccessToken));
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
