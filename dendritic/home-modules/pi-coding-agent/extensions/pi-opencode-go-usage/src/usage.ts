/** OpenCode Go usage lookup and human-readable formatting. */

import { redactSecrets } from "./security.ts";

const USAGE_URL = "https://opencode.ai/zen/go/v1/usage";
const PROVIDER_ID = "opencode-go";
const REQUEST_TIMEOUT_MS = 10_000;
const CLIENT_USER_AGENT = "pi-opencode-go-usage/1.0";

export interface OpenCodeGoUsageWindow {
	status: string;
	percent: number;
	resetsAt?: string;
}

export interface OpenCodeGoUsage {
	rolling: OpenCodeGoUsageWindow;
	weekly: OpenCodeGoUsageWindow;
	monthly: OpenCodeGoUsageWindow;
}

export interface OpenCodeGoAuthResolver {
	getApiKeyForProvider(provider: string): Promise<string | undefined>;
}

function isRecord(value: unknown): value is Record<string, unknown> {
	return typeof value === "object" && value !== null && !Array.isArray(value);
}

function asFiniteNumber(value: unknown): number | undefined {
	return typeof value === "number" && Number.isFinite(value) ? value : undefined;
}

function parseWindow(value: unknown, label: string): OpenCodeGoUsageWindow {
	if (!isRecord(value)) {
		throw new Error(`OpenCode Go usage response missing ${label} window`);
	}

	const percent = asFiniteNumber(value.percent ?? value.usagePercent);
	if (percent === undefined) {
		throw new Error(`OpenCode Go usage response missing ${label} percentage`);
	}

	const status =
		typeof value.status === "string"
			? value.status
			: percent >= 100
				? "rate-limited"
				: "ok";

	return {
		status,
		percent: Math.max(0, Math.min(100, percent)),
		resetsAt: typeof value.resetsAt === "string" ? value.resetsAt : undefined,
	};
}

/** Parse the first-party usage response, accepting the current and legacy window names. */
export function parseOpenCodeGoUsage(value: unknown): OpenCodeGoUsage {
	if (!isRecord(value)) {
		throw new Error("OpenCode Go usage endpoint returned an invalid response");
	}

	const usage = isRecord(value.usage) ? value.usage : value;
	const rolling = usage.rolling ?? usage.rollingUsage;
	const weekly = usage.weekly ?? usage.weeklyUsage;
	const monthly = usage.monthly ?? usage.monthlyUsage;

	return {
		rolling: parseWindow(rolling, "rolling"),
		weekly: parseWindow(weekly, "weekly"),
		monthly: parseWindow(monthly, "monthly"),
	};
}

function responseErrorMessage(body: string): string | undefined {
	const text = body.trim();
	if (!text) return undefined;

	try {
		const parsed: unknown = JSON.parse(text);
		if (isRecord(parsed)) {
			const error = parsed.error;
			if (isRecord(error) && typeof error.message === "string") return error.message;
			if (typeof error === "string") return error;
			if (typeof parsed.message === "string") return parsed.message;
		}
	} catch {
		// Fall through to a bounded, redacted response body.
	}

	return text.slice(0, 300);
}

function usageRequestError(status: number, statusText: string, body: string): Error {
	if (status === 401) {
		return new Error(
			"OpenCode Go authentication failed. Run /login and select OpenCode Go, or check OPENCODE_API_KEY.",
		);
	}
	if (status === 403) {
		return new Error("OpenCode Go subscription is not available for this API key.");
	}

	const detail = responseErrorMessage(body);
	const suffix = detail ? `: ${redactSecrets(detail)}` : "";
	const statusLabel = [status, statusText].filter(Boolean).join(" ");
	return new Error(`OpenCode Go usage request failed (${statusLabel})${suffix}`);
}

/** Resolve the key Pi uses for OpenCode Go, with environment fallbacks for standalone use. */
export async function resolveOpenCodeGoApiKey(resolver: OpenCodeGoAuthResolver): Promise<string> {
	const providerKey = await resolver.getApiKeyForProvider(PROVIDER_ID);
	const environmentKey =
		process.env.OPENCODE_API_KEY || process.env.OPENCODE_GO_API_KEY || process.env.PI_OPENCODE_GO_API_KEY;
	const apiKey = [providerKey, environmentKey]
		.map((value) => value?.trim())
		.find((value): value is string => Boolean(value));

	if (!apiKey) {
		throw new Error(
			"OpenCode Go API key is not configured. Run /login and select OpenCode Go, or set OPENCODE_API_KEY.",
		);
	}
	return apiKey;
}

/** Fetch current server-computed rolling, weekly, and monthly usage windows. */
export async function getOpenCodeGoUsage(apiKey: string, sessionId: string): Promise<OpenCodeGoUsage> {
	const response = await fetch(USAGE_URL, {
		headers: {
			Accept: "application/json",
			Authorization: `Bearer ${apiKey.trim()}`,
			"User-Agent": CLIENT_USER_AGENT,
			"x-opencode-session": sessionId.trim() || "pi-usage",
			"x-opencode-client": "pi",
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
		throw new Error("OpenCode Go usage endpoint returned invalid JSON");
	}
	return parseOpenCodeGoUsage(payload);
}

function formatPercent(percent: number): string {
	return Number.isInteger(percent) ? `${percent}%` : `${percent.toFixed(1)}%`;
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

function formatWindow(label: string, window: OpenCodeGoUsageWindow, now: number): string {
	const percent = formatPercent(window.percent).padStart(4);
	const reset = formatResetTime(window.resetsAt, now);
	return `  ${label.padEnd(14)}${percent}${" ".repeat(12)}${reset}`;
}

export function formatOpenCodeGoUsage(usage: OpenCodeGoUsage, now = Date.now()): string {
	return [
		"Go-Subscription",
		"Low cost coding models for everyone • Learn more",
		"",
		formatWindow("Rolling usage", usage.rolling, now),
		formatWindow("Weekly usage", usage.weekly, now),
		formatWindow("Monthly usage", usage.monthly, now),
	].join("\n");
}
