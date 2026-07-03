## Search and grep

Prefer the built-in `grep` tool over `bash`/`rg` for code search. It respects `.gitignore` and enforces output limits.

Keep searches concise to avoid polluting context:

- Set a low `limit` (default 100; use 20–50 when exploring).
- Narrow with `glob` (e.g. `*.ts`, `src/**/*.tsx`) instead of searching the whole tree.
- Use `path` to scope to the relevant directory.
- Avoid broad patterns that match generated, vendored, or cached files.

Do not search or read from cache, build, or bundle paths unless the task explicitly requires it. Skip or exclude:

- `node_modules/`, `vendor/`, `.venv/`, `dist/`, `build/`, `out/`, `.next/`, `target/`
- `__pycache__/`, `.cache/`, `.mypy_cache/`, `.pytest_cache/`, `.turbo/`
- `*.bundle.js`, `*.min.js`, `*.map`, lockfiles, and large binary blobs

If results are truncated or noisy, refine the pattern, tighten `glob`/`path`, or lower `limit` — do not widen the search.
