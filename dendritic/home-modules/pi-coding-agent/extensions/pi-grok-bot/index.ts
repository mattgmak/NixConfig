// Grok Bot has no public Bot API: its routine webhook is the only call surface. The
// POST starts a run, and the answer lands in the Bot chat, not in the HTTP body.
import { Type } from "@earendil-works/pi-ai";
import { defineTool, type ExtensionAPI } from "@earendil-works/pi-coding-agent";

type Route = { url: string; key: string };

function readRoute(): Route | null {
  const url = process.env.GROK_BOT_WEBHOOK_URL?.trim() ?? "";
  const key = process.env.GROK_BOT_WEBHOOK_KEY?.trim() ?? "";
  return url === "" || key === "" ? null : { url, key };
}

const askGrokBot = defineTool({
  name: "ask_grok_bot",
  label: "Ask Grok Bot",
  description:
    "Start a Grok Bot run through its routine webhook. " +
    "The HTTP reply confirms the start only. " +
    "Read the answer in the Grok Bot app.",
  parameters: Type.Object({
    instruction: Type.String({
      description: "Text the Bot receives with the routine instruction",
    }),
  }),
  async execute(_toolCallId, params, signal) {
    const route = readRoute();
    if (route === null) {
      return {
        content: [
          {
            type: "text",
            text: "Set GROK_BOT_WEBHOOK_URL and GROK_BOT_WEBHOOK_KEY first. Both fields show on the routine page in the Grok Bot app.",
          },
        ],
        details: { error: "missing_webhook_config" },
        isError: true,
      };
    }

    try {
      const response = await fetch(route.url, {
        method: "POST",
        signal,
        headers: {
          Authorization: `Bearer ${route.key}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ text: params.instruction }),
      });
      const body = (await response.text()).slice(0, 2000);
      const details = { status: response.status, url: route.url, body };

      if (!response.ok) {
        return {
          content: [
            {
              type: "text",
              text: `The webhook returned HTTP ${response.status}. No run started. Check that the routine is active and that the key is current.`,
            },
          ],
          details,
          isError: true,
        };
      }

      return {
        content: [
          {
            type: "text",
            text: `The webhook returned HTTP ${response.status}. The Bot started the run. Read the result in the Grok Bot app.`,
          },
        ],
        details,
      };
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      return {
        content: [{ type: "text", text: `The webhook call failed: ${message}` }],
        details: { url: route.url, error: message },
        isError: true,
      };
    }
  },
});

export default function piGrokBotExtension(pi: ExtensionAPI): void {
  pi.registerTool(askGrokBot);
}
