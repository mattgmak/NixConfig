export function cursorEnv(name: string): string | undefined {
	return (
		process.env[`PI_CURSOR_${name}`] ||
		process.env[`CURSOR_${name}`] ||
		process.env[`PI_CURSOR_PROVIDER_${name}`]
	);
}

export function isRecord(value: unknown): value is Record<string, unknown> {
	return typeof value === "object" && value !== null && !Array.isArray(value);
}
