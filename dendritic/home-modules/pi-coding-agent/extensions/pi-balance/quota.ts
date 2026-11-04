/**
 * Quota probes for the balance router.
 *
 * Each provider publishes usage in its own shape. Every probe reduces its
 * responses to the percentage used in the tightest window, or undefined when
 * the data is unreadable.
 */

import { execSync } from "node:child_process";
import { readFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

export type QuotaKey = "commandcode" | "opencode-go" | "clinepass";

export interface ProviderQuota {
  /** Percentage used in the tightest window, 0 to 100. */
  usedPercent: number;
  /** Earliest window reset as epoch seconds, when the API reports one. */
  soonestReset: number | null;
  exhausted: boolean;
}

const FETCH_TIMEOUT_MS = 5000;

/** Below this dollar balance a route cannot serve a typical request. */
const MIN_BALANCE = 0.25;

type Json = Record<string, unknown>;

function record(value: unknown): Json | undefined {
  return typeof value === "object" && value !== null && !Array.isArray(value)
    ? (value as Json)
    : undefined;
}

function count(value: unknown): number | undefined {
  return typeof value === "number" && Number.isFinite(value) && value >= 0 ? value : undefined;
}

function epochSeconds(value: unknown): number | undefined {
  if (typeof value === "number" && Number.isFinite(value) && value > 0) {
    return value >= 1e12 ? Math.round(value / 1000) : value;
  }
  if (typeof value === "string" && value.length > 0) {
    const parsed = Date.parse(value);
    return Number.isNaN(parsed) ? undefined : Math.round(parsed / 1000);
  }
  return undefined;
}

async function getJson(url: string, key: string): Promise<Json | undefined> {
  try {
    const response = await fetch(url, {
      headers: { accept: "application/json", authorization: `Bearer ${key}` },
      signal: AbortSignal.timeout(FETCH_TIMEOUT_MS),
    });
    if (!response.ok) return undefined;
    return record(await response.json());
  } catch {
    return undefined;
  }
}

/**
 * Resolve a provider key from the environment, then from auth.json.
 *
 * Pi stores keys as a plain string, as { type, key }, or as a "!command"
 * string that resolves through a secret manager.
 */
export function apiKey(envName: string, ...providerIds: string[]): string | undefined {
  const fromEnv = process.env[envName];
  if (fromEnv) return fromEnv;
  const auth = authFile();
  if (!auth) return undefined;
  const roots: Json[] = [auth];
  const providers = record(auth.providers);
  if (providers) roots.push(providers);
  for (const id of providerIds) {
    for (const root of roots) {
      const value = credential(root[id]);
      if (value) return value;
    }
  }
  return undefined;
}

function authFile(): Json | undefined {
  const dir = process.env.PI_CODING_AGENT_DIR ?? join(homedir(), ".pi", "agent");
  try {
    return record(JSON.parse(readFileSync(join(dir, "auth.json"), "utf8")));
  } catch {
    return undefined;
  }
}

function credential(value: unknown): string | undefined {
  const direct = stringCredential(value);
  if (direct) return direct;
  const fields = record(value);
  if (!fields) return undefined;
  for (const field of ["apiKey", "key", "access", "token"]) {
    const nested = stringCredential(fields[field]);
    if (nested) return nested;
  }
  return undefined;
}

function stringCredential(value: unknown): string | undefined {
  if (typeof value !== "string" || value.length === 0) return undefined;
  if (!value.startsWith("!")) return value;
  try {
    return execSync(value.slice(1), { encoding: "utf8", timeout: 5000 }).trim() || undefined;
  } catch {
    return undefined;
  }
}

interface Window {
  used: number;
  cap: number;
  exceeded: boolean;
  reset: number | undefined;
}

function windowOf(value: unknown): Window | undefined {
  const entry = record(value);
  if (!entry) return undefined;
  const used = count(entry.used);
  const cap = count(entry.cap);
  if (used === undefined || cap === undefined || (used === 0 && cap === 0)) return undefined;
  return { used, cap, exceeded: entry.exceeded === true, reset: epochSeconds(entry.resetAt) };
}

/**
 * Command Code: GET /alpha/billing/credits gives window caps and the leftover
 * balance. The windows reset on their own clock, so the period spend from
 * /alpha/usage/summary sets the pool total and the real used percentage.
 */
export async function commandCodeQuota(key: string): Promise<ProviderQuota | undefined> {
  const base = process.env.COMMAND_CODE_API_BASE ?? "https://api.commandcode.ai";
  const [json, summary] = await Promise.all([
    getJson(`${base}/alpha/billing/credits`, key),
    getJson(`${base}/alpha/usage/summary`, key),
  ]);
  if (!json && !summary) return undefined;
  const limits = record(json?.windowLimits);
  const windows = [windowOf(limits?.fiveHour), windowOf(limits?.weekly)].filter(
    (entry): entry is Window => entry !== undefined,
  );
  const credits = record(json?.credits);
  const remaining = credits
    ? count(credits.remainingCredits) ??
      [count(credits.monthlyCredits), count(credits.purchasedCredits), count(credits.freeCredits)]
        .map((value) => value ?? 0)
        .reduce((total, value) => total + value, 0)
    : undefined;
  const spent = count(summary?.totalCost);
  let poolPercent: number | undefined;
  if (spent !== undefined && remaining !== undefined && spent + remaining > 0) {
    poolPercent = (spent / (spent + remaining)) * 100;
  }
  if (windows.length === 0 && poolPercent === undefined) return undefined;
  const resets = windows
    .map((entry) => entry.reset)
    .filter((value): value is number => value !== undefined);
  const windowPercent = windows.length
    ? Math.max(...windows.map((entry) => (entry.cap > 0 ? (entry.used / entry.cap) * 100 : 0)))
    : 0;
  return {
    usedPercent: Math.max(windowPercent, poolPercent ?? 0),
    soonestReset: resets.length ? Math.min(...resets) : null,
    exhausted:
      windows.some((entry) => entry.exceeded) ||
      (poolPercent !== undefined && poolPercent >= 99.5) ||
      (remaining !== undefined && remaining <= MIN_BALANCE),
  };
}

/** OpenCode Go: GET /zen/go/v1/usage returns rolling, weekly, and monthly windows. */
export async function openCodeGoQuota(key: string): Promise<ProviderQuota | undefined> {
  const base = process.env.OPENCODE_API_BASE ?? "https://opencode.ai";
  const json = await getJson(`${base}/zen/go/v1/usage`, key);
  const usage = record(json?.usage);
  if (!usage) return undefined;
  const resets: number[] = [];
  let usedPercent = 0;
  let exhausted = false;
  for (const name of ["rolling", "weekly", "monthly"] as const) {
    const window = record(usage[name]);
    if (!window) continue;
    const percent = count(window.percent);
    if (percent !== undefined) usedPercent = Math.max(usedPercent, percent);
    if (window.status === "exceeded" || (percent !== undefined && percent >= 100)) {
      exhausted = true;
    }
    const reset = epochSeconds(window.resetsAt);
    if (reset !== undefined) resets.push(reset);
  }
  return { usedPercent, soonestReset: resets.length ? Math.min(...resets) : null, exhausted };
}

/** ClinePass: GET /api/v1/users/me/plan/usage-limits returns percentUsed per window. */
export async function clinepassQuota(key: string): Promise<ProviderQuota | undefined> {
  const base = process.env.CLINE_API_BASE ?? "https://api.cline.bot";
  const json = await getJson(`${base}/api/v1/users/me/plan/usage-limits`, key);
  const limits = record(json?.data)?.limits;
  if (!Array.isArray(limits)) return undefined;
  let usedPercent = 0;
  for (const entry of limits) {
    const percent = count(record(entry)?.percentUsed);
    if (percent !== undefined) usedPercent = Math.max(usedPercent, percent);
  }
  return { usedPercent, soonestReset: null, exhausted: usedPercent >= 100 };
}
