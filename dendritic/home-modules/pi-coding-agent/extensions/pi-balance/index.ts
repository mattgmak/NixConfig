/**
 * Balance provider: one model id that spreads usage over every subscription
 * that serves DeepSeek V4.1 Flash.
 *
 * Register `balance/deepseek-v4.1-flash` as a virtual model. `route` runs
 * before each request, reads cached quota snapshots, and returns the physical
 * model with the most headroom. Sticky routing keeps prompt caches warm.
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import {
  apiKey,
  clinepassQuota,
  commandCodeQuota,
  openCodeGoQuota,
  type ProviderQuota,
  type QuotaKey,
} from "./quota.ts";

const CACHE_TTL_MS = 60_000;
const FIRST_WAIT_MS = 4_000;
const FALLBACK_COOLDOWN_MS = 600_000;
const HYSTERESIS_PERCENT = 20;
const UNKNOWN_PERCENT = 100.5;

interface Route {
  key: QuotaKey;
  provider: string;
  modelId: string;
  secret: () => string | undefined;
  probe: (key: string) => Promise<ProviderQuota | undefined>;
}

const ROUTES: readonly Route[] = [
  {
    key: "commandcode",
    provider: "commandcode",
    modelId: "deepseek/deepseek-v4.1-flash",
    secret: () => apiKey("COMMAND_CODE_API_KEY", "commandcode"),
    probe: commandCodeQuota,
  },
  {
    key: "opencode-go",
    provider: "opencode-go",
    modelId: "deepseek-v4.1-flash",
    secret: () => apiKey("OPENCODE_API_KEY", "opencode-go", "opencode"),
    probe: openCodeGoQuota,
  },
  {
    key: "clinepass",
    provider: "clinepass",
    modelId: "cline-pass/deepseek-v4.1-flash-1017",
    secret: () => apiKey("CLINE_API_KEY", "clinepass", "cline"),
    probe: clinepassQuota,
  },
];

interface BalanceState {
  route?: QuotaKey;
  cooldowns?: Partial<Record<QuotaKey, number>>;
}

type Quotas = Partial<Record<QuotaKey, ProviderQuota>>;

function routeKeyFor(provider: string, id: string): QuotaKey | undefined {
  return ROUTES.find((route) => route.provider === provider && route.modelId === id)?.key;
}

function percentOf(quotas: Quotas, key: QuotaKey): number {
  return quotas[key]?.usedPercent ?? UNKNOWN_PERCENT;
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => {
    setTimeout(resolve, ms);
  });
}

/**
 * Order the routes best first. Closed routes (failed, cooling down, or
 * exhausted) drop out, and an empty result falls back to every other route.
 */
function rank(
  reason: string,
  previousKey: QuotaKey | undefined,
  failedKey: QuotaKey | undefined,
  quotas: Quotas,
  cooldowns: Partial<Record<QuotaKey, number>>,
  now: number,
): Route[] {
  const open = ROUTES.filter((route) => {
    if (route.key === failedKey) return false;
    const until = cooldowns[route.key];
    if (until !== undefined && until > now) return false;
    return !quotas[route.key]?.exhausted;
  }).sort((a, b) => percentOf(quotas, a.key) - percentOf(quotas, b.key));
  if (open.length === 0) return ROUTES.filter((route) => route.key !== failedKey);
  if (reason === "retry" || reason === "direct" || !previousKey) return open;
  const sticky = open.find((route) => route.key === previousKey);
  if (!sticky) return open;
  const keep =
    reason === "continuation" ||
    percentOf(quotas, previousKey) <= percentOf(quotas, open[0].key) + HYSTERESIS_PERCENT;
  return keep ? [sticky, ...open.filter((route) => route !== sticky)] : open;
}

export default function (pi: ExtensionAPI) {
  let cache: { at: number; values: Quotas } | undefined;
  let pending: Promise<void> | undefined;

  function startRefresh(): Promise<void> | undefined {
    if (pending) return pending;
    const running = (async () => {
      const values: Quotas = {};
      await Promise.all(
        ROUTES.map(async (route) => {
          const key = route.secret();
          if (!key) return;
          const quota = await route.probe(key);
          if (quota) values[route.key] = quota;
        }),
      );
      cache = { at: Date.now(), values };
    })();
    pending = running;
    const clear = () => {
      if (pending === running) pending = undefined;
    };
    running.then(clear, clear);
    return running;
  }

  /** Return cached quotas, refreshing in the background when stale. */
  async function quotas(now: number): Promise<Quotas> {
    if (!cache || now - cache.at > CACHE_TTL_MS) {
      const refresh = startRefresh();
      if (!cache && refresh) await Promise.race([refresh, sleep(FIRST_WAIT_MS)]);
    }
    return cache?.values ?? {};
  }

  pi.registerVirtualModel<BalanceState>({
    provider: "balance",
    id: "deepseek-v4.1-flash",
    name: "DeepSeek V4.1 Flash (balanced)",
    thinkingLevels: ["off", "high"],
    contextWindow: 1_000_000,
    maxTokens: 384_000,
    input: ["text", "image"],
    async route(request, ctx) {
      const now = Date.now();
      const values = await quotas(now);
      const failedKey = request.failed
        ? routeKeyFor(request.failed.model.provider, request.failed.model.id)
        : undefined;
      const previousKey = request.previous
        ? routeKeyFor(request.previous.model.provider, request.previous.model.id)
        : undefined;
      const cooldowns = { ...(request.state?.cooldowns ?? {}) };
      if (failedKey) {
        const reset = values[failedKey]?.soonestReset;
        cooldowns[failedKey] = reset ? reset * 1000 : now + FALLBACK_COOLDOWN_MS;
      }
      const thinkingLevel = request.thinkingLevel ?? "high";
      const debug = process.env.PI_BALANCE_DEBUG === "1";
      for (const route of rank(request.reason, previousKey, failedKey, values, cooldowns, now)) {
        const model = ctx.modelRegistry.find(route.provider, route.modelId);
        if (!model) continue;
        if (debug) {
          const quota = values[route.key];
          console.error(
            `[pi-balance] ${request.reason} -> ${route.key} ` +
              `${quota ? `${quota.usedPercent.toFixed(1)}% used` : "no quota"}`,
          );
        }
        if (request.reason === "direct") return { model, thinkingLevel };
        const state: BalanceState = {
          route: route.key,
          ...(Object.keys(cooldowns).length > 0 ? { cooldowns } : {}),
        };
        if (JSON.stringify(state) === JSON.stringify(request.state ?? {})) {
          return { model, thinkingLevel };
        }
        return { model, thinkingLevel, state };
      }
      throw new Error(`balance/deepseek-v4.1-flash: no registered model for ${ROUTES.length} routes`);
    },
  });
}
