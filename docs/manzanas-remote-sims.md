# Remote simulators: manzanas MCP over Tailscale

Goal: an agent session on any tailnet node leases a `macmini` simulator and drives it through MCP.

Last checked: 29 Oct 2026 on `macmini`, manzanas 0.7.0, argent 0.30.0, Tailscale service `svc:manzanas`.

## Two MCP servers, two jobs

| Server | Job | Transport |
|---|---|---|
| `manzanas mcp` | Lease, boot, UI driving, screenshots, journal | stdio. Runs on the agent node as a client of `manzanasd` |
| `argent mcp` | Chromium, debugger, profiler, Android | stdio. Serves only the host it runs on |

manzanas owns simulator lifecycle and leases. argent keeps the capabilities manzanas lacks.

`manzanas mcp` ships inside the client binary. It is not a separate build, and it needs no wrapper.

## What the flake already wires

`dendritic/hosts/MacMini.nix` holds every part. No new module is needed.

| Part | Line | Value |
|---|---|---|
| Port constant | `:215` | `manzanasPort = 7433` |
| Lease daemon | `:694` | `launchd.agents.manzanasd` |
| Bind address | `:712` | `-addr 127.0.0.1:${manzanasPort}` |
| Pool and profile | `:711`, `:724` | `MANZANASD_POOL_SIMS`, `-pool-slim-profile qasafe` |
| Logs | `:732-733` | `~/Library/Logs/manzanasd.std{out,err}.log` |
| Publish job | `:580` | `launchd.daemons.tailscale-serve-sim` |
| Publish command | `:591` | `tailscale serve --yes --service=svc:manzanas --https=443 127.0.0.1:7433` |

The daemon binds loopback and Tailscale Serve publishes it. Keep that shape.

## No bearer token

The daemon accepts an empty `MANZANASD_AUTH_TOKEN`, and empty means no auth. The flag help text states it: "empty disables auth". No flag refuses startup in that case.

The Tailscale ACL on `svc:manzanas` is the only gate now. Two consequences follow.

1. Any node with an ACL grant can drive the fleet. Check the grant before you rely on it.
2. `POST /v0/devices` spawns host processes and needs a token. That endpoint closes without one. The pool still boots, because `MANZANASD_POOL_SIMS` loads it at launch.

Do not bind a public address. A bind to `0.0.0.0` or the tailnet IP skips Serve and accepts plaintext from every interface.

## Agent config

`dendritic/home-modules/pi-coding-agent/mcp.json` holds the server entry. `pi-coding-agent.nix` replaces the command with an absolute store path.

```json
"manzanas": {
  "command": "manzanas",
  "args": ["--daemon", "https://manzanas.dab-octatonic.ts.net", "mcp"]
}
```

The `--daemon` flag is global, so it comes before the `mcp` subcommand. Put it after, and the server fails with `unexpected argument "--daemon"`. The `MANZANASD_ADDR` variable carries the same value when a flag does not fit.

The entry carries no `toolExposure`, so all 28 tools stay behind one namespace. An agent names `mcp__manzanas` in its `tools:` line. The parent session reaches the same tools through the `mcp` gateway.

## Lease then drive

The MCP server enforces lease ownership, so get a lease first.

```
lease_acquire  -labels ios26,iphone-17-pro -ttl 3600 -wait -reset erase
targets        → confirms the leased target_udid
ui_tree        → element tree with a stable hash
tap_element    / type_into_element / scroll_to_element
screenshot     or audit
lease_release
```

The server instructions push that element path: "PREFER the element tools to drive the UI". Element actions return `ui_changed`, a before and after tree-hash comparison, so an agent skips a screenshot to detect change.

`run` replays a whole `SPEC.yaml` in one call. Use it for repeatable flows.

The CLI reaches the same daemon when a shell step is simpler.

```bash
URL=https://manzanas.dab-octatonic.ts.net

manzanas --daemon "$URL" lease acquire \
  -labels ios26,iphone-17-pro -ttl 3600 -wait -reset erase -purpose "device pass"

manzanas --daemon "$URL" --lease "$LEASE" boot "$UDID"
manzanas --daemon "$URL" --lease "$LEASE" screenshot -o shot.png
manzanas --daemon "$URL" lease release "$LEASE"
```

`--lease` is a subcommand flag, not a global one. `-o` is mandatory on `screenshot`.

A lease carries `lease_id`, `target_udid`, `labels`, `state`, `expires_at`, `agent_id`, `purpose`, `queue_position`, and `ttl_seconds`.

## The 28 manzanas tools

| Group | Tools |
|---|---|
| Lease | `lease_acquire`, `lease_release`, `lease_renew` |
| Fleet | `targets` |
| Lifecycle | `state`, `app` |
| Element driving | `ui_tree`, `tap_element`, `tap_template`, `type_into_element`, `scroll_to_element`, `wait_for_element`, `wait_tree_stable`, `wait_for_stable` |
| Raw input | `tap`, `swipe`, `type_text`, `button` |
| Observation | `screenshot`, `observe`, `audit`, `scroll_until`, `scroll_collect` |
| Recording | `record_start`, `record_stop` |
| Flow | `run`, `run_status`, `journal_export` |

## argent stays for its own capabilities

argent keeps Chromium control, the React and native debuggers, the profilers, network log inspection, and Android. It keeps no simulator lane that matters now.

A remote node reaches argent through its own server, because `argent mcp` speaks stdio only.

```bash
# On macmini
argent server start --host 0.0.0.0 --port 3001

# On the agent node
argent link argent://<token>@macmini:3001
argent mcp
```

### Why no provider shim

argent reads device descriptors from `~/.argent/providers` and accepts an `ext:<provider>:<udid>` id. That path does not help here. Read the contract facts below.

| Contract fact | Result |
|---|---|
| Interaction proxying needs `capabilities: ["simulator-server"]` plus a provider endpoint that speaks argent's own `/api/*` protocol | Needs a new server. `simbridge` is not one |
| Lifecycle calls throw `EXTERNAL_DEVICE_LIFECYCLE_REFUSED` for any provider device | argent cannot boot a leased sim, and manzanas owns boot |
| Install and launch always call local `xcrun simctl` on the argent host | No remote gain |
| A descriptor whose `nativeId` matches a real sim removes that sim from argent's own list | The shim takes away more than it adds |

So a shim costs more code than `manzanas mcp`, and it weakens the argent side. Do not build it.

## Measured behaviour, 29 Oct 2026

| Probe | Result |
|---|---|
| `manzanas --json lease ls` with no token, against a tokenised daemon | 401 text |
| `manzanas --json lease ls` with the agenix token | `{"leases": []}`, exit 0 |
| `manzanas --daemon 100.67.196.51:7433 lease ls` | `connection refused`. Direct IP fails by design |
| `manzanas --daemon https://manzanas.dab-octatonic.ts.net lease ls` | Lease table, exit 0 |
| `tailscale serve status` | `https://manzanas.dab-octatonic.ts.net (tailnet only) (svc:manzanas)` → `proxy http://127.0.0.1:7433` |
| `argent mcp` transports in the bundle | `StdioServerTransport` only |
| `manzanas --daemon 127.0.0.1:7433 mcp` with an MCP `initialize` frame | `connected to manzanasd`, serverInfo returned |
| `MANZANASD_ADDR` env plus `manzanas mcp` | Same handshake, no flag |
| `tools/list` over that session | 28 tools |
| `manzanas mcp --daemon URL` | `unexpected argument "--daemon"` |
| Tokenless daemon, `lease ls` with no token | `{"leases": []}`, exit 0 |
| Tokenless daemon, `manzanas mcp` with no token | `connected`, 28 tools |
| `pi mcp list` with the new entry | `manzanas: connected, 28 tools` |

## Setup from scratch

1. **Admin console.** Create the service `svc:manzanas`. Serve refuses a service name that does not exist.
2. **ACL.** Grant the nodes that need simulators access to `svc:manzanas` on port 443. The token is gone, so this grant is the only gate.
3. **Host module.** Copy the rows above from `MacMini.nix`. Keep the loopback bind.
4. **Switch.** Run `nh` on `macmini`. The build is the user's step, not an agent's.
5. **Reload the agent.** Run the two `launchctl` calls in the failure table. The switch writes the plist and leaves the old process running.
6. **Verify.** Run `manzanas --daemon "$URL" lease ls` from a second node. It must exit 0 without a token.

## Failure modes

| Symptom | Cause | Fix |
|---|---|---|
| `connection refused` on `IP:7433` | Loopback bind, by design | Use the service URL |
| `connection refused` on the service URL | `tailscale-serve-sim` down | `launchctl kickstart gui/$(id -u)/org.nixos.tailscale-serve-sim` |
| `unauthorized` after the token removal | The daemon still runs the old generation. A plist change does not restart a launchd job | Run `launchctl bootout gui/$(id -u)/org.nixos.manzanasd`, then `launchctl bootstrap gui/$(id -u) /Library/LaunchAgents/org.nixos.manzanasd.plist` |
| `not_found: lease not found` | Lease expired or released | Get a new lease, then reinstall the app |
| `svc:manzanas` not found | Service absent in the admin console | Create it, then restart the Serve job |
| `mcp__manzanas` missing in an agent | The agent `tools:` line omits it | Name it, or reach the tools through the `mcp` gateway |

## Verification task: run the fleet from `ramsay`

Owner: an agent on `ramsay`. This task proves the whole remote path with real simulator work.

### Preconditions

Check each item before the first lease. Stop and report on any miss.

1. `tailscale status` shows `ramsay` and `macmini` as peers.
2. The ACL grants `ramsay` access to `svc:manzanas` on port 443.
3. `manzanas` runs on `ramsay` and reports its version. Install the flake package when absent.
4. `manzanas --daemon "$URL" lease ls` exits 0 with no token.
5. `pi mcp list` shows `manzanas: connected`, or the `mcp__manzanas` tools answer.

### Steps

Run them through MCP, so the task tests the agent path and not only the CLI.

1. `lease_acquire` with `-labels ios26,iphone-17-pro`, `-ttl 1800`, `-wait`, `-reset erase`.
2. `targets`. Record `lease_id` and `target_udid`.
3. `state`. The device must read `Booted`.
4. `app` with a launch action, then `ui_tree`. Confirm the tree hash exists.
5. `tap_element` on one element from the tree. Confirm `ui_changed` is true.
6. `screenshot` to a local file. Confirm the file holds pixels and not a blank frame.
7. `journal_export`. Confirm the journal names every call above.
8. `lease_release`. Confirm `lease ls` no longer lists the lease.
9. Repeat steps 1 to 8 through the CLI once, with `--lease`, to prove both paths agree.

### Pass criteria

| Item | Target |
|---|---|
| Lease round trip | One run gets a lease and releases it, with no 401 and no 5xx |
| Latency | Each MCP call under 5 s on a warm target |
| Ownership | A second lease on the same target queues, and the daemon reports `queue_position` |
| Tree hash | `ui_changed` follows a real tap |
| Evidence | Screenshot, journal, and both transcripts land in `$TMPDIR/agent-tmp/manzanas-ramsay/` |

### Stop rules

- Do not shut down, restart, or erase a target that another lease holds.
- Do not call `POST /v0/devices`.
- Do not reboot the host or restart CoreSimulator.
- Release the lease on any failure, then report the verbatim error.

### Report

Return the evidence paths, the latency table, and any gap against the pass criteria. Do not claim success from a tool reply alone. A blank screenshot or a missing journal entry fails the run.

## Unverified as of 29 Oct 2026

- **Reachability from another node.** The SSH probe to `goofeus` stopped at an unverified host key.
- **ACL grant.** The console config is not readable from this host.
- **`argent link` against a manzanas-leased sim.** argent lists local CoreSimulator devices, so a leased sim should appear. Test with `list-devices` before any work relies on it.

## Rollback

Stop the Serve job. The daemon keeps serving loopback, so on-Mac lanes keep working.

```bash
launchctl bootout gui/$(id -u)/org.nixos.tailscale-serve-sim
```

To restore the bearer token, add the `age.secrets.manzanasd-auth-token` block back and pass `MANZANASD_AUTH_TOKEN` to `manzanasd`.

## Related

- `docs/droid-handbook.md` for host conventions.
- Agent rules: no simulator run without the user's word. See the app tree `AGENTS.md`.
