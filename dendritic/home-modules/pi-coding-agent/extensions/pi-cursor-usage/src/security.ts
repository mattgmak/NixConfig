/** Redact JWTs, bearer tokens, and common secret keys from diagnostics/errors. */
export function redactSecrets(text: string): string {
	return text
		.replace(/\beyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\b/g, "[redacted-jwt]")
		.replace(/\bBearer\s+[A-Za-z0-9._~+/-]+=*/gi, "Bearer [redacted]")
		.replace(
			/("?(?:access_token|refresh_token|accessToken|refreshToken|token|authorization|code_verifier)"?\s*[:=]\s*")[^"]*(")/gi,
			"$1[redacted]$2",
		)
		.replace(
			/("?(?:access_token|refresh_token|accessToken|refreshToken|token|authorization|code_verifier)"?\s*[:=]\s*)[^\s&,}]+/gi,
			"$1[redacted]",
		);
}
