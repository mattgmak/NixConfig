/**
 * Balance provider: one model id that spreads usage over every subscription
 * that serves DeepSeek V4.1 Flash.
 *
 * Register `balance/deepseek-v4.1-flash` as a virtual model. `route` picks the
 * least used route on the first request and keeps it for the whole session. A
 * route changes only when it exhausts or fails, because every switch costs a
 * prompt-cache miss.
 *
 * /balanced-usage prints every window of every route plus the route it picks.
 * /balanced-route prints the route the current session uses.
 */

import {
  VIRTUAL_MODEL_STATE_ENTRY,
  type ExtensionAPI,
  type SessionEntry,
  type VirtualModelStateData,
} from "@earendil-works/pi-coding-agent";
import {
  apiKey,
  clinepassQuota,
  commandCodeQuota,
  openCodeGoQuota,
  type ProviderQuota,
  type QuotaKey,
} from "./quota.ts";
import { formatRoute, formatUsage, type UsageRow } from "./format.ts";

const VIRTUAL_PROVIDER = "balance";
const VIRTUAL_ID = "deepseek-v4.1-flash";
const CACHE_TTL_MS = 60_000;
const FIRST_WAIT_MS = 4_000;
const FALLBACK_COOLDOWN_MS = 600_000;
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
  /** Epoch milliseconds when the route was set. */
  since?: number;
  /** Reason of the request that set the route. */
  reason?: string;
  /** Thinking level returned with the route. */
  level?: string;
  cooldowns?: Partial<Record<QuotaKey, number>>;
}

type Quotas = Partial<Record<QuotaKey, ProviderQuota>>;

function routeKeyFor(provider: string, id: string): QuotaKey | undefined {
  return ROUTES.find((route) => route.provider === provider && route.modelId === id)?.key;
}

function routeByKey(key: string): Route | undefined {
  return ROUTES.find((route) => route.key === key);
}

function percentOf(quotas: Quotas, key: QuotaKey): number {
  return quotas[key]?.usedPercent ?? UNKNOWN_PERCENT;
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => {
    setTimeout(resolve, ms);
  });
}

/** A route serves when it is not failed, not cooling down, and not exhausted. */
function isOpen(
  route: Route,
  quotas: Quotas,
  cooldowns: Partial<Record<QuotaKey, number>>,
  now: number,
  failedKey?: QuotaKey,
): boolean {
  if (route.key === failedKey) return false;
  const until = cooldowns[route.key];
  if (until !== undefined && until > now) return false;
  return !quotas[route.key]?.exhausted;
}

/**
 * Order the routes best first. Closed routes (failed, cooling down, or
 * exhausted) drop out, and an empty result falls back to every other route. A
 * session keeps its current route while that route stays open.
 */
function rank(
  reason: string,
  previousKey: QuotaKey | undefined,
  failedKey: QuotaKey | undefined,
  quotas: Quotas,
  cooldowns: Partial<Record<QuotaKey, number>>,
  now: number,
): Route[] {
  const open = ROUTES.filter((route) => isOpen(route, quotas, cooldowns, now, failedKey)).sort(
    (a, b) => percentOf(quotas, a.key) - percentOf(quotas, b.key),
  );
  if (open.length === 0) return ROUTES.filter((route) => route.key !== failedKey);
  if (reason === "retry" || reason === "direct" || !previousKey) return open;
  const sticky = open.find((route) => route.key === previousKey);
  if (!sticky) return open;
  return [sticky, ...open.filter((route) => route !== sticky)];
}

/** Read the router state Pi stores on the session branch. */
function branchState(entries: readonly SessionEntry[]): BalanceState | undefined {
  for (let index = entries.length - 1; index >= 0; index -= 1) {
    const entry = entries[index];
    if (entry.type !== "custom" || entry.customType !== VIRTUAL_MODEL_STATE_ENTRY) continue;
    const data = entry.data as VirtualModelStateData<BalanceState> | undefined;
    if (data?.provider !== VIRTUAL_PROVIDER || data.modelId !== VIRTUAL_ID) continue;
    return data.state;
  }
  return undefined;
}

interface Entry {
  route: Route;
  quota: ProviderQuota | undefined;
  /** Why the route cannot serve, or undefined when it can. */
  closed?: string;
}

interface Plan {
  /** Table rows in ROUTES order, each carrying its rank. */
  rows: UsageRow[];
  /** Failover order entries, best first. */
  order: string[];
  /** Route a request would use, or undefined when every route is closed. */
  pick?: Route;
}

function oneDecimal(percent: number): string {
  return percent >= UNKNOWN_PERCENT ? "--" : `${percent.toFixed(1)}%`;
}

/** Rank every route by usage and mark the closed ones, for both commands. */
function plan(values: Quotas, state: BalanceState | undefined, now: number): Plan {
  const cooldowns = state?.cooldowns ?? {};
  const entries: Entry[] = ROUTES.map((route) => {
    const until = cooldowns[route.key];
    if (until !== undefined && until > now) {
      return { route, quota: values[route.key], closed: `closed ${remaining(until, now)}` };
    }
    if (values[route.key]?.exhausted) return { route, quota: values[route.key], closed: "closed" };
    return { route, quota: values[route.key] };
  });
  const ranked = [...entries].sort(
    (a, b) => percentOf(values, a.route.key) - percentOf(values, b.route.key),
  );
  const pick = entries.find((entry) => entry.closed === undefined)?.route;
  const rows = entries.map((entry) => {
    const rank = ranked.indexOf(entry) + 1;
    const inUse = entry.route.key === state?.route;
    const picked = entry.route === pick;
    const status = [
      entry.closed,
      picked && inUse ? "pick · in use" : picked ? "pick" : inUse ? "in use" : undefined,
      entry.quota?.remainingCredits === undefined
        ? undefined
        : `$${entry.quota.remainingCredits.toFixed(2)}`,
    ]
      .filter((part) => part !== undefined)
      .join(" ");
    return {
      label: entry.route.key,
      windows: entry.quota?.windows ?? [],
      rank,
      ...(status ? { tail: status } : {}),
    };
  });
  const order = ranked.map((entry) => {
    const head = `${ranked.indexOf(entry) + 1} ${entry.route.key}`;
    const percent = oneDecimal(percentOf(values, entry.route.key));
    if (entry.closed) return `${head} ${percent} (${entry.closed})`;
    return entry.route.key === state?.route ? `${head} ${percent} (in use)` : `${head} ${percent}`;
  });
  return { rows, order, ...(pick ? { pick } : {}) };
}

function remaining(until: number, now: number): string {
  const minutes = Math.ceil((until - now) / 60_000);
  if (minutes < 60) return `${minutes}m`;
  return `${Math.floor(minutes / 60)}h ${String(minutes % 60).padStart(2, "0")}m`;
}

function clock(ms: number): string {
  const date = new Date(ms);
  const hours = String(date.getHours()).padStart(2, "0");
  const minutes = String(date.getMinutes()).padStart(2, "0");
  return `${hours}:${minutes}`;
}

export default function (pi: ExtensionAPI) {
  let cache: { at: number; values: Quotas } | undefined;
  let pending: Promise<Quotas> | undefined;

  /** Fetch every route now and fill the cache. Concurrent calls share one fetch. */
  function refresh(): Promise<Quotas> {
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
      return values;
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
      const running = refresh();
      if (!cache) await Promise.race([running, sleep(FIRST_WAIT_MS)]);
    }
    return cache?.values ?? {};
  }

  pi.registerVirtualModel<BalanceState>({
    provider: VIRTUAL_PROVIDER,
    id: VIRTUAL_ID,
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
          process.stderr.write(
            `[pi-balance] ${request.reason} -> ${route.key} ` +
              `${quota ? `${quota.usedPercent.toFixed(1)}% used` : "no quota"}\n`,
          );
        }
        if (request.reason === "direct") return { model, thinkingLevel };
        const keep = request.state?.route === route.key ? request.state : undefined;
        const state: BalanceState = {
          route: route.key,
          since: keep?.since ?? now,
          reason: keep?.reason ?? request.reason,
          level: keep?.level ?? thinkingLevel,
          ...(Object.keys(cooldowns).length > 0 ? { cooldowns } : {}),
        };
        if (JSON.stringify(state) === JSON.stringify(request.state ?? {})) {
          return { model, thinkingLevel };
        }
        return { model, thinkingLevel, state };
      }
      throw new Error(`${VIRTUAL_PROVIDER}/${VIRTUAL_ID}: no registered model for ${ROUTES.length} routes`);
    },
  });

  pi.registerCommand("balanced-usage", {
    description: "Show usage for all three balance routes and the route it picks",
    async handler(_args, ctx) {
      const now = Date.now();
      const values = await refresh();
      const state = branchState(ctx.sessionManager.getBranch());
      const { rows, pick } = plan(values, state, now);
      const header = [
        "Balance · DeepSeek V4.1 Flash",
        pick
          ? `Pick    ${pick.key} → ${pick.modelId} (${state?.level ?? ctx.thinkingLevel ?? "high"}) · ${oneDecimal(percentOf(values, pick.key))}`
          : "Pick    none · every route closed",
      ];
      const text = formatUsage(header, rows);
      if (ctx.hasUI) ctx.ui.notify(text, "info");
      else console.log(text);
    },
  });

  pi.registerCommand("balanced-route", {
    description: "Show the model the balance virtual model routes to now",
    async handler(_args, ctx) {
      const now = Date.now();
      const values = await quotas(now);
      const state = branchState(ctx.sessionManager.getBranch());
      const { order, pick } = plan(values, state, now);
      const routed = state?.route
        ? `${state.route} → ${routeByKey(state.route)?.modelId ?? "unknown"}${state.level ? ` (${state.level})` : ""}`
        : pick
          ? `not set · would route ${pick.key} → ${pick.modelId}`
          : "none · every route closed";
      const set =
        state?.since === undefined
          ? undefined
          : `${clock(state.since)} by ${state.reason ?? "unknown"} request, kept for the prompt cache`;
      const text = formatRoute({
        title: `Balance · DeepSeek V4.1 Flash`,
        routed,
        ...(set ? { set } : {}),
        order,
      });
      if (ctx.hasUI) ctx.ui.notify(text, "info");
      else console.log(text);
    },
  });
}
