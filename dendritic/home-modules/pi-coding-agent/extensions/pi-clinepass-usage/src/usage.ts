/** ClinePass usage lookup and human-readable formatting. */

import { redactSecrets } from "./security.ts";

const USAGE_PATH = "/api/v1/users/me/plan/usage-limits";
const DEFAULT_API_BASE = "https://api.cline.bot";
const PROVIDER_IDS = ["clinepass", "cline"];
const REQUEST_TIMEOUT_MS = 10_000;
const CLIENT_USER_AGENT = "pi-clinepass-usage/1.0";

export type ClinePassWindowType = "five_hour" | "weekly" | "monthly";

export interface ClinePassUsageWindow {
	type: ClinePassWindowType;
	percent: number;
	resetsAt?: string;
}

export interface ClinePassUsage {
	/** Windows the API reported, ordered 5-hour, weekly, monthly. */
	windows: ClinePassUsageWindow[];
	planName?: string;
}

export interface ClinePassAuthResolver {
	getApiKeyForProvider(provider: string): Promise<string | undefined>;
}

const WINDOW_ORDER: readonly ClinePassWindowType[] = ["five_hour", "weekly", "monthly"];

const WINDOW_LABELS: Record<ClinePassWindowType, string> = {
	five_hour: "5-hour usage",
	weekly: "Weekly usage",
	monthly: "Monthly usage",
};

/** Normalized `type` values that name the three subscription windows. */
const WINDOW_ALIASES: Record<string, ClinePassWindowType> = {
	fivehour: "five_hour",
	fivehours: "five_hour",
	"5hour": "five_hour",
	"5h": "five_hour",
	week: "weekly",
	weekly: "weekly",
	month: "monthly",
	monthly: "monthly",
};

function isRecord(value: unknown): value is Record<string, unknown> {
	return typeof value === "object" && value !== null && !Array.isArray(value);
}

function asFiniteNumber(value: unknown): number | undefined {
	return typeof value === "number" && Number.isFinite(value) ? value : undefined;
}

function stringField(source: Record<string, unknown>, fields: readonly string[]): string | undefined {
	for (const field of fields) {
		const value = source[field];
		if (typeof value === "string" && value.trim()) return value.trim();
	}
	return undefined;
}

function windowType(value: unknown): ClinePassWindowType | undefined {
	if (typeof value !== "string") return undefined;
	return WINDOW_ALIASES[value.toLowerCase().replace(/[-_\s]/g, "")];
}

/** Parse one limit entry. Unknown window types stay out of the report. */
function parseWindow(value: unknown): ClinePassUsageWindow | undefined {
	const entry = isRecord(value) ? value : undefined;
	if (!entry) return undefined;

	const type = windowType(stringField(entry, ["type", "limitType", "windowType"]) ?? "");
	if (!type) return undefined;

	const percent = asFiniteNumber(entry.percentUsed ?? entry.percent ?? entry.usagePercent);
	if (percent === undefined) return undefined;

	return {
		type,
		percent: Math.max(0, Math.min(100, percent)),
		resetsAt: stringField(entry, ["resetsAt", "resetAt", "resets_at"]),
	};
}

function planName(data: Record<string, unknown>): string | undefined {
	const direct = stringField(data, ["plan", "planName", "tier"]);
	if (direct) return direct;

	for (const field of ["plan", "subscription", "planDetails"]) {
		const nested = isRecord(data[field]) ? (data[field] as Record<string, unknown>) : undefined;
		const name = nested && stringField(nested, ["name", "tier", "planName"]);
		if (name) return name;
	}
	return undefined;
}

function errorMessage(payload: Record<string, unknown>): string | undefined {
	const error = payload.error;
	if (isRecord(error)) return stringField(error, ["message", "error"]);
	if (typeof error === "string") return error.trim() || undefined;
	return stringField(payload, ["message", "detail"]);
}

/**
 * Parse the first-party usage-limits response.
 *
 * The endpoint answers `{ success, error?, data: { limits: [{ type, percentUsed,
 * resetsAt? }] } }`. `data` is optional in some error replies, so the root object
 * is read as a fallback.
 */
export function parseClinePassUsage(value: unknown): ClinePassUsage {
	const payload = isRecord(value) ? value : undefined;
	if (!payload) {
		throw new Error("ClinePass usage endpoint returned an invalid response");
	}

	if (payload.success === false) {
		const detail = errorMessage(payload);
		throw new Error(
			`ClinePass usage unavailable${detail ? `: ${redactSecrets(detail)}` : ""}`,
		);
	}

	const data = isRecord(payload.data) ? payload.data : payload;
	const rawLimits = Array.isArray(data.limits)
		? data.limits
		: Array.isArray(payload.limits)
			? payload.limits
			: [];
	const limits = rawLimits
		.map(parseWindow)
		.filter((window): window is ClinePassUsageWindow => window !== undefined);

	if (limits.length === 0) {
		throw new Error("ClinePass reported no usage limits for this API key");
	}

	return {
		windows: WINDOW_ORDER.flatMap((type) =>
			limits.filter((window) => window.type === type).slice(0, 1),
		),
		planName: planName(data),
	};
}

function usageUrl(): string {
	const base = (process.env.CLINE_API_BASE ?? "").trim().replace(/\/+$/, "");
	return `${base || DEFAULT_API_BASE}${USAGE_PATH}`;
}

function responseErrorMessage(body: string): string | undefined {
	const text = body.trim();
	if (!text) return undefined;

	try {
		const parsed: unknown = JSON.parse(text);
		if (isRecord(parsed)) {
			const message = errorMessage(parsed);
			if (message) return message;
		}
	} catch {
		// Fall through to a bounded, redacted response body.
	}

	return text.slice(0, 300);
}

function usageRequestError(status: number, statusText: string, body: string): Error {
	if (status === 401) {
		return new Error(
			"ClinePass authentication failed. Run /login and select ClinePass, or check CLINE_API_KEY.",
		);
	}
	if (status === 403) {
		return new Error("ClinePass subscription is not available for this API key.");
	}
	if (status === 404) {
		return new Error("ClinePass usage endpoint not found. Check CLINE_API_BASE.");
	}

	const detail = responseErrorMessage(body);
	const suffix = detail ? `: ${redactSecrets(detail)}` : "";
	const statusLabel = [status, statusText].filter(Boolean).join(" ");
	return new Error(`ClinePass usage request failed (${statusLabel})${suffix}`);
}

async function keyFromProvider(
	resolver: ClinePassAuthResolver,
	providerId: string,
): Promise<string | undefined> {
	try {
		return await resolver.getApiKeyForProvider(providerId);
	} catch {
		return undefined;
	}
}

/**
 * Resolve the key Pi uses for ClinePass.
 *
 * Pi answers for provider-registered credentials, which covers both the static
 * API key and the rotating WorkOS token. The env vars keep the module usable
 * outside pi.
 */
export async function resolveClinePassApiKey(resolver: ClinePassAuthResolver): Promise<string> {
	const providerKeys = await Promise.all(
		PROVIDER_IDS.map((providerId) => keyFromProvider(resolver, providerId)),
	);
	const candidates = [providerKeys[0], providerKeys[1], process.env.CLINEPASS_API_KEY, process.env.CLINE_API_KEY];
	const apiKey = candidates.map((value) => value?.trim()).find((value): value is string => Boolean(value));

	if (!apiKey) {
		throw new Error(
			"ClinePass API key is not configured. Run /login and select ClinePass, or set CLINE_API_KEY.",
		);
	}
	return apiKey;
}

/** Fetch the current server-computed usage windows. */
export async function getClinePassUsage(apiKey: string): Promise<ClinePassUsage> {
	const response = await fetch(usageUrl(), {
		headers: {
			Accept: "application/json",
			Authorization: `Bearer ${apiKey}`,
			"User-Agent": CLIENT_USER_AGENT,
		},
		signal: AbortSignal.timeout(REQUEST_TIMEOUT_MS),
	});
	const body = await response.text();

	if (!response.ok) {
		throw usageRequestError(response.status, response.statusText, body);
	}

	let payload: unknown;
	try {
		payload = JSON.parse(body);
	} catch {
		throw new Error("ClinePass usage endpoint returned invalid JSON");
	}
	return parseClinePassUsage(payload);
}

function formatPercent(percent: number): string {
	return Number.isInteger(percent) ? `${percent}%` : `${percent.toFixed(1)}%`;
}

function renderProgressBar(percent: number, width: number): string {
	const clamped = Math.max(0, Math.min(100, percent));
	const filled = clamped > 0 ? Math.max(1, Math.round((clamped / 100) * width)) : 0;
	return "█".repeat(filled) + "░".repeat(width - filled);
}

function progressBarWidth(terminalWidth: number): number {
	if (terminalWidth < 47) return 4;
	if (terminalWidth < 60) return 6;
	if (terminalWidth < 74) return 8;
	return 20;
}

function formatResetTime(resetsAt: string | undefined, now: number): string {
	if (!resetsAt) return "Resets unavailable";

	const resetMs = Date.parse(resetsAt);
	if (!Number.isFinite(resetMs)) return "Resets unavailable";

	const seconds = Math.floor((resetMs - now) / 1000);
	if (seconds <= 0) return "Resets now";

	const days = Math.floor(seconds / 86_400);
	if (days > 0) {
		const hours = Math.floor((seconds % 86_400) / 3_600);
		return `Resets in ${days}d ${hours}h`;
	}

	const hours = Math.floor(seconds / 3_600);
	if (hours > 0) {
		const minutes = Math.floor((seconds % 3_600) / 60);
		return `Resets in ${hours}h ${minutes}m`;
	}

	const minutes = Math.floor(seconds / 60);
	if (minutes > 0) return `Resets in ${minutes}m`;
	return "Resets in a few seconds";
}

function formatWindow(
	window: ClinePassUsageWindow,
	now: number,
	barWidth: number,
	terminalWidth: number,
): string {
	const label = WINDOW_LABELS[window.type];
	const percent = formatPercent(window.percent).padStart(6);
	const bar = renderProgressBar(window.percent, barWidth);
	const reset = formatResetTime(window.resetsAt, now);
	if (terminalWidth < 45) return `  ${label} ${percent} ${bar}\n  ${reset}`;
	return `  ${label.padEnd(14)}${percent} ${bar} ${reset}`;
}

export function formatClinePassUsage(
	usage: ClinePassUsage,
	now = Date.now(),
	terminalWidth = process.stdout.columns || 80,
): string {
	const width = Number.isFinite(terminalWidth) && terminalWidth > 0 ? terminalWidth : 80;
	const barWidth = progressBarWidth(width);
	const title = usage.planName ? `ClinePass ${usage.planName}` : "ClinePass";
	return [
		title,
		"Cline subscription usage limits • app.cline.bot",
		"",
		...usage.windows.map((window) => formatWindow(window, now, barWidth, width)),
	].join("\n");
}
