#!/usr/bin/env node
// Probe free LLM endpoints used by the pi-blackhole extension.
// Ranks candidates by tool-call validity and latency.

import { readFileSync, existsSync, writeFileSync } from "node:fs"
import { homedir } from "node:os"
import { join } from "node:path"
import { randomUUID } from "node:crypto"

const HOME = homedir()
const TIMEOUT_MS = 60_000
const MAX_TOKENS = 512
const CONCURRENCY = 4

const PROVIDERS = {
  openrouter: {
    url: "https://openrouter.ai/api/v1/chat/completions",
    env: ["OPENROUTER_API_KEY"],
    secrets: ["openrouter-api-key", "openrouter"],
    auth: ["openrouter"],
    headers: () => ({ "HTTP-Referer": "https://localhost", "X-Title": "blackhole-probe" }),
  },
  "opencode-go": {
    url: "https://opencode.ai/inference/go/v1/chat/completions",
    env: ["OPENCODE_API_KEY"],
    secrets: ["opencode-api-key"],
    auth: ["opencode-go", "opencode"],
    // endpoint answers 400 when the session header is absent
    headers: () => ({ "x-opencode-session": randomUUID(), "x-opencode-client": "pi" }),
  },
  commandcode: {
    url: "https://api.commandcode.ai/provider/v1/chat/completions",
    env: ["COMMAND_CODE_API_KEY", "COMMANDCODE_API_KEY"],
    secrets: ["commandcode-api-key", "command-code-api-key"],
    auth: ["commandcode", "command-code"],
    headers: () => ({}),
  },
}

const USAGE = `Usage: node scripts/blackhole-probe.mjs [options]

Probe free LLM endpoints for tool-call support.

Input: candidate lines "provider<TAB>model-id" from --file, else stdin.

Options:
  --file <path>    Read candidate TSV from path.
  --config <path>  Also read pi-blackhole-config.json and collect every
                   model, observerModel, reflectorModel, dropperModel and
                   *FallbackModels entry.
  --json <path>    Write full result objects to path as JSON.
  --help, -h       Show this help.

Providers: ${Object.keys(PROVIDERS).join(", ")}.
Exit code is 0 when the arguments parse, even when every model fails.`

function secretFile(name) {
  const paths = [
    join(HOME, ".config", "age", "secrets", name),
    join(HOME, ".config", "agenix", name),
    `/run/user/${process.getuid?.() ?? 1000}/agenix/${name}`,
    `/run/agenix/${name}`,
  ]
  return paths.find((p) => existsSync(p))
}

function fromSecret(name) {
  const p = secretFile(name)
  if (!p) return undefined
  try {
    const v = readFileSync(p, "utf8").trim()
    return v || undefined
  } catch {
    return undefined
  }
}

function fromPiAuth(keys) {
  const p = join(HOME, ".pi", "agent", "auth.json")
  if (!existsSync(p)) return undefined
  try {
    const j = JSON.parse(readFileSync(p, "utf8"))
    for (const k of keys) {
      const v = j?.[k]
      if (typeof v === "string" && v) return v
      if (v && typeof v === "object") {
        const s = v.key ?? v.access ?? v.apiKey
        if (typeof s === "string" && s) return s
      }
    }
    const flat = j?.apiKey
    if (typeof flat === "string" && flat) return flat
  } catch {}
  return undefined
}

function resolveKey(spec) {
  for (const n of spec.env) {
    if (process.env[n]) return { key: process.env[n], via: `env ${n}` }
  }
  for (const s of spec.secrets) {
    const v = fromSecret(s)
    if (v) return { key: v, via: `secrets/${s}` }
  }
  const v = fromPiAuth(spec.auth)
  if (v) return { key: v, via: "~/.pi/agent/auth.json" }
  return undefined
}

const TOOLS = [
  {
    type: "function",
    function: {
      name: "ping",
      description: "Ping",
      parameters: { type: "object", properties: { value: { type: "string" } }, required: ["value"] },
    },
  },
]

function body(model) {
  return {
    model,
    messages: [{ role: "user", content: "Call the ping tool. Do not answer in text." }],
    tools: TOOLS,
    tool_choice: "auto",
    max_tokens: MAX_TOKENS,
    stream: false,
  }
}

const flat = (s) => String(s ?? "").replace(/\s+/g, " ").trim().slice(0, 80)

async function once(spec, model, key) {
  const ac = new AbortController()
  const timer = setTimeout(() => ac.abort(), TIMEOUT_MS)
  const started = Date.now()
  try {
    const res = await fetch(spec.url, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${key}`,
        "Content-Type": "application/json",
        ...spec.headers(),
      },
      body: JSON.stringify(body(model)),
      signal: ac.signal,
    })
    const text = await res.text()
    const ms = Date.now() - started
    let json
    try {
      json = JSON.parse(text)
    } catch {}
    const choice = json?.choices?.[0]
    const calls = choice?.message?.tool_calls
    return {
      http: res.status,
      ms,
      toolCall: Array.isArray(calls) && calls.length > 0,
      finish: choice?.finish_reason ?? null,
      note: flat(json?.error?.message ?? (json ? "" : text)),
    }
  } catch (e) {
    const msg = e?.name === "AbortError" ? "timeout 60s" : String(e?.message ?? e)
    return { http: 0, ms: Date.now() - started, toolCall: false, finish: null, note: flat(msg) }
  } finally {
    clearTimeout(timer)
  }
}

// network failure, timeout, 429 and 5xx retry once; 403 and 404 stay final
const retryable = (r) => r.http === 0 || r.http === 429 || r.http >= 500

const sleep = (ms) => new Promise((s) => setTimeout(s, ms))

async function probe(cand, keys) {
  const spec = PROVIDERS[cand.provider]
  const key = spec ? keys[cand.provider] : undefined
  if (!spec) return { ...cand, http: -1, ms: 0, toolCall: false, finish: null, note: "unknown provider" }
  if (!key) return { ...cand, http: -1, ms: 0, toolCall: false, finish: null, note: "no api key" }

  let r = await once(spec, cand.model, key.key)
  if (retryable(r)) {
    await sleep(1200)
    r = await once(spec, cand.model, key.key)
  }

  let note = r.note
  if (r.finish === "length") note = flat([note, "truncated by max_tokens"].filter(Boolean).join("; "))
  return { provider: cand.provider, model: cand.model, ...r, note }
}

async function pool(items, n, fn) {
  const out = new Array(items.length)
  let next = 0
  const workers = Array.from({ length: Math.min(n, items.length) }, async () => {
    while (next < items.length) {
      const i = next++
      out[i] = await fn(items[i], i)
    }
  })
  await Promise.all(workers)
  return out
}

function parseTsv(text) {
  const out = []
  for (const line of text.split(/\r?\n/)) {
    const s = line.trim()
    if (!s || s.startsWith("#")) continue
    const [provider, ...rest] = s.split("\t")
    const model = rest.join("\t").trim()
    if (!provider.trim() || !model) continue
    out.push({ provider: provider.trim(), model })
  }
  return out
}

const SINGLE_KEYS = ["model", "observerModel", "reflectorModel", "dropperModel"]

function parseConfig(text) {
  const j = JSON.parse(text)
  const out = []
  const push = (e) => {
    if (e && typeof e.provider === "string" && typeof e.id === "string") {
      out.push({ provider: e.provider, model: e.id })
    }
  }
  for (const k of SINGLE_KEYS) push(j?.[k])
  for (const [k, v] of Object.entries(j ?? {})) {
    if (k.endsWith("FallbackModels") && Array.isArray(v)) v.forEach(push)
  }
  return out
}

const dedupe = (list) => {
  const seen = new Set()
  return list.filter((c) => {
    const k = `${c.provider}\t${c.model}`
    if (seen.has(k)) return false
    seen.add(k)
    return true
  })
}

function parseArgs(argv) {
  const opts = { file: null, json: null, config: null, help: false }
  const valued = { "--file": "file", "--json": "json", "--config": "config" }
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i]
    if (a === "--help" || a === "-h") {
      opts.help = true
      continue
    }
    const slot = valued[a]
    if (slot) {
      const v = argv[++i]
      if (!v || v.startsWith("--")) throw new Error(`missing value for ${a}`)
      opts[slot] = v
      continue
    }
    throw new Error(`unknown argument: ${a}`)
  }
  return opts
}

function readStdin() {
  return new Promise((resolve, reject) => {
    if (process.stdin.isTTY) return resolve("")
    let buf = ""
    process.stdin.setEncoding("utf8")
    process.stdin.on("data", (c) => (buf += c))
    process.stdin.on("end", () => resolve(buf))
    process.stdin.on("error", reject)
  })
}

async function main() {
  let opts
  try {
    opts = parseArgs(process.argv.slice(2))
  } catch (e) {
    process.stderr.write(`${e.message}\n\n${USAGE}\n`)
    process.exitCode = 2
    return 2
  }
  if (opts.help) {
    process.stdout.write(`${USAGE}\n`)
    return 0
  }

  const cands = []
  if (opts.file) cands.push(...parseTsv(readFileSync(opts.file, "utf8")))
  else cands.push(...parseTsv(await readStdin()))
  if (opts.config) cands.push(...parseConfig(readFileSync(opts.config, "utf8")))

  const list = dedupe(cands)
  const keys = {}
  for (const name of Object.keys(PROVIDERS)) keys[name] = resolveKey(PROVIDERS[name])

  const prov = Object.entries(keys)
    .map(([p, k]) => `${p} via ${k ? k.via : "missing"}`)
    .join(", ")
  process.stderr.write(`keys: ${prov}\n`)

  const rows = list.length
    ? await pool(list, CONCURRENCY, (c) => probe(c, keys))
    : []

  const lines = ["provider\tmodel\thttp\tms\ttoolCall\tfinish\tnote"]
  for (const r of rows) {
    lines.push(
      [r.provider, r.model, r.http, r.ms, r.toolCall ? "yes" : "no", r.finish ?? "-", r.note].join("\t"),
    )
  }
  process.stdout.write(`${lines.join("\n")}\n`)

  if (opts.json) writeFileSync(opts.json, JSON.stringify(rows, null, 2))

  const ok = rows.filter((r) => r.toolCall)
  const failed = rows.length - ok.length
  process.stderr.write(`ok ${ok.length}, failed ${failed}\n`)
  if (ok.length) {
    const ranked = [...ok].sort((a, b) => a.ms - b.ms).map((r) => `${r.provider}/${r.model} ${r.ms}ms`)
    process.stderr.write(`ok by ms: ${ranked.join(", ")}\n`)
  }
  return 0
}

main().then(
  (code) => {
    process.exitCode = code ?? 0
  },
  (e) => {
    process.stderr.write(`${e?.stack ?? e}\n`)
    process.exitCode = 1
  },
)
