# vscode-telescope bridge — agent handoff

Last updated: 2026-05-22

## Goal

Provide **native Telescope.nvim UX inside VSCode** via **vscode-neovim**, using the same keymaps as standalone Neovim, without a custom VSCode extension.

User presses a telescope keybind in embedded vscode-neovim → real Telescope TUI runs in a VSCode terminal sidecar → selection is applied back in VSCode via `require('vscode')`.

## Repo layout

| Path | Role |
|------|------|
| `dendritic/home-modules/neovim/config/lua/plugins/vscode-telescope/` | Bridge implementation (this feature) |
| `dendritic/home-modules/neovim/config/lua/plugins/telescope/setup.lua` | Shared telescope setup (native + sidecar) |
| `dendritic/home-modules/neovim/config/lua/plugins/telescope/multigrep.lua` | Custom multigrep picker (shared) |
| `dendritic/home-modules/neovim/config/lua/plugins.lua` | Native telescope + keymaps (`cond = not is_vscode`) |
| `dendritic/home-modules/neovim/config/lua/config.lua` | VSCode branch; calls `require('plugins.vscode-telescope').setup()` |
| `~/.config/nvim/lua` | Symlinked to the above `config/lua` tree |

Init order:

```lua
require('plugins')   -- lazy.nvim plugins; native telescope when not vscode
require('config')    -- vscode branch + vscode-telescope setup
```

## Architecture

Two Neovim processes cooperate:

```
┌─────────────────────────────┐         ┌──────────────────────────────┐
│  Embedded nvim (vscode)     │         │  Sidecar nvim (terminal)     │
│  role: embedded             │         │  role: sidecar               │
│                             │         │                              │
│  keymap → bridge.run_picker │ ──────► │  sidecar.run_request         │
│  poll result JSON file      │  RPC /  │  telescope picker TUI        │
│  vscode_actions.apply       │  files  │  write result JSON file      │
│  panel maximize/restore     │         │  --listen socket             │
└─────────────────────────────┘         └──────────────────────────────┘
```

### IPC artifacts

All under `vim.fn.stdpath('data')` (typically `~/.local/share/nvim/`):

| File | Purpose |
|------|---------|
| `vscode-telescope.sock` | Neovim `--listen` socket for sidecar |
| `vscode-telescope.sock.ready` | Ready marker: `pid`, `timestamp`, `BRIDGE_VERSION` |
| `vscode-telescope.sock.pending` | One-line path to boot-time request JSON |
| `vscode-telescope/debug.log` | NDJSON debug log (embedded + sidecar) |

Temp request/result JSON files use `vim.fn.tempname()`.

### Request JSON shape

```json
{
  "picker": "find_files",
  "opts": {},
  "file": "/optional/for/current_buffer_fuzzy_find",
  "result_path": "/tmp/nvim.user/xxx.json"
}
```

### Result JSON shape

Success:

```json
{
  "picker": "find_files",
  "action": "default",
  "path": "/abs/path/to/file",
  "line": 1,
  "col": 1
}
```

Cancel:

```json
{ "cancelled": true }
```

Error:

```json
{ "cancelled": true, "error": "message" }
```

## Module reference

| Module | Responsibility |
|--------|----------------|
| `init.lua` | VSCode keymaps, debug commands |
| `bridge.lua` | Orchestration: spawn/reuse sidecar, poll result, finish |
| `terminal.lua` | VSCode terminal spawn, panel toggle, kill sidecar, workspace root |
| `sidecar.lua` | Runs in terminal nvim; runs telescope; writes results |
| `rpc.lua` | `io.popen` ping/dispatch (`--remote-expr`); module reload on RPC |
| `vscode_actions.lua` | Open file/line in VSCode via `vscode.eval` |
| `paths.lua` | Paths + `BRIDGE_VERSION` |
| `log.lua` | NDJSON logging with `role` (`embedded` / `sidecar`) |
| `json.lua` | JSON read/write |
| `assert.lua` | Soft/hard assertions for debug |
| `test.lua` | Lightweight self-tests (no integration) |

## End-to-end flow

1. **Embedded** keymap → `bridge.run_picker(picker, opts)`
2. Write request JSON; set `pending = true`
3. `terminal.maximize_panel()` (VSCode workbench command)
4. `ensure_sidecar(request_path)`:
   - **Reuse** if `rpc.ping()` OK (socket + version match)
   - **Spawn** otherwise: kill stale PID, write `.pending`, open terminal:
     ```bash
     /bin/bash -lc 'cd ROOT && rm -f SOCK READY && exec NVIM --listen SOCK -c "lua require(...sidecar).start()"'
     ```
5. **Sidecar boot** (`sidecar.start()`):
   - Load telescope via `plugins.telescope.setup.ensure_loaded()`
   - Set `g:vscode_telescope_ready`, write `.ready`
   - If `.pending` exists, defer 500ms → `run_request`
6. **Reuse path**: `rpc.close_pickers()` then `rpc.dispatch_async(request_path)`
   - Remote expr reloads sidecar module and calls `run_request`
7. **Sidecar** `run_request`:
   - Close stale pickers
   - Open bridged telescope picker
   - **Block** until result file exists or picker closes (see below)
8. **Embedded** polls result file (600 × 150ms max)
9. `finish`: apply in VSCode, restore panel, delete temp files, `pending = false`

## Critical technical learnings

### 1. Telescope `:find()` is non-blocking

`Picker:find()` ends with `main_loop()` where `main_loop = async.void(...)`. The picker mounts asynchronously; **do not** assume `builtin.find_files(opts)` blocks until the user picks.

**Wrong (original bug):**

```lua
picker(...)
if vim.fn.filereadable(result_path) ~= 1 then
  write_result({ cancelled = true })  -- fires immediately
end
```

**Correct:** After opening picker, poll until:
- result file exists, OR
- all active `TelescopePrompt` buffers are gone (with grace period for nested pickers)

See `wait_for_picker_mount()` and `wait_for_picker_result()` in `sidecar.lua`.

### 2. Stale sidecar processes

Embedded nvim reloads config often; **sidecar nvim keeps old Lua in memory** until killed.

Symptoms:
- Instant `run_request_cancelled` on reuse
- `write_result_missing_path` when user picks later
- Orphan telescope TUIs from dead sessions

Mitigations (implemented):
- `paths.BRIDGE_VERSION` (currently **3**) stored in `.ready` and `g:vscode_telescope_bridge_version`
- `rpc.ping()` rejects sidecars below current version
- `terminal.kill_sidecar()` before spawn (SIGTERM via PID in `.ready`)
- `package.loaded['plugins.vscode-telescope.sidecar'] = nil` on every RPC
- `sidecar.close_pickers()` at start of each `run_request`
- `:TelescopeBridgeRestart` kills sidecar manually

**Always bump `BRIDGE_VERSION` in `paths.lua` when changing sidecar protocol or lifecycle behavior.**

### 3. Default telescope mappings open files in sidecar

`attach_mappings` must intercept selection. Current approach:

```lua
actions.select_default:replace(select_default)
actions.select_horizontal:replace(select_horizontal)
-- Esc/C-c → write { cancelled = true }
return true
```

Do **not** rely on default `<CR>` — it opens the file in the sidecar terminal instead of writing bridge JSON.

### 4. RPC constraints (Neovim 0.12)

- No `--remote-lua`; use `--remote-expr` + `luaeval(...)`
- Ping uses vimscript: `g:vscode_telescope_ready == v:true`
- Embedded nvim: prefer `io.popen` over `vim.system` (empty in vscode-neovim)
- Spawn via `/bin/bash -lc` (user may use nushell as default shell)

### 5. Terminal spawn gotcha

If sidecar nvim is still running, `term.sendText(cmd)` may feed the command **into nvim** instead of the shell.

Mitigations:
- Kill sidecar by PID before spawn
- Send Ctrl-C (`\u0003`) before spawn command in `terminal.lua`

## VSCode keymaps (telescope bridge)

Registered in `init.lua` → `bridge.run_picker`:

| Key | Picker |
|-----|--------|
| `<leader><leader>` | `find_files` |
| `<leader>jf` | `current_buffer_fuzzy_find` (active VSCode file) |
| `<leader>jg` | `multigrep` |
| `<leader>jp` | `pickers` (cached) |
| `<leader>jv` | `resume` |
| `<leader>jj` | `builtin` (bridge menu) |
| `<leader>jh` | `help_tags` |

Visual variants pass `default_text` from selection where applicable.

**Still workbench (not telescope):**

| Key | VSCode command |
|-----|----------------|
| `<leader>js` | `workbench.action.gotoSymbol` |
| `<leader>ja` | `workbench.action.showAllSymbols` |
| `<leader>jc` | `breadcrumbs.focusAndSelect` |
| `<leader>k` | `workbench.action.showAllEditorsByMostRecentlyUsed` |

Native equivalents live in `plugins.lua` (`<leader>js`, buffers, LSP, etc.).

## Debug tooling

Globals in `config.lua`:

```lua
vim.g.vscode_telescope_debug = true
vim.g.vscode_telescope_debug_strict = false
```

Commands:

| Command | Purpose |
|---------|---------|
| `:TelescopeBridgeLog` | Open debug log |
| `:TelescopeBridgeLogClear` | Clear log |
| `:TelescopeBridgeLogTail [N]` | Notify last N lines |
| `:TelescopeBridgeStatus` | Ping, socket, version info |
| `:TelescopeBridgePing` | Sidecar ping only |
| `:TelescopeBridgeRestart` | Kill sidecar process |
| `:TelescopeBridgeTest` | Unit-ish tests (json, paths) |

Log format: one JSON object per line with `role`, `event`, `ts`, `data`, optional `session`.

### Healthy pick sequence (what to look for)

```
embedded  keymap_pick
embedded  run_picker_start
embedded  panel_maximize
embedded  ensure_sidecar_reuse | ensure_sidecar_spawn
sidecar   run_request_start
sidecar   run_request_loaded
sidecar   picker_open
sidecar   picker_mounted
[user picks]
sidecar   write_result          ← must appear BEFORE embedded finish
sidecar   run_request_wait_done { status: "result" }
sidecar   run_request_done
embedded  result_ready
embedded  finish                ← path set, cancelled false
embedded  panel_restore
embedded  apply via vscode_actions
```

### Failure signatures

| Log event | Likely cause |
|-----------|--------------|
| `run_request_cancelled` immediately after `run_request_loaded` | Old sidecar code OR mount/wait bug |
| `write_result_missing_path` | Pick happened after result path cleared / stale picker |
| `run_picker_busy` | Previous request still `pending` (90s timeout possible) |
| `wait_for_result_poll` forever | Sidecar waiting, user picking in wrong/stale TUI |
| `ensure_sidecar_restart_stale` | Version mismatch; sidecar being replaced |
| `picker_mount_timeout` | Terminal/sidecar didn't open telescope |

## Current status (as of handoff)

**Implemented but not fully verified end-to-end by user.**

Recent fixes (BRIDGE_VERSION 3):
- Non-blocking `:find()` wait loop
- Result path in closures (no global `current_result_path`)
- Sidecar kill + version gate + module reload
- `actions.select_default:replace`
- Valid prompt detection (`TelescopePrompt` buftype)
- Nested picker grace period (300ms)

User's last logs still showed failures when:
1. Reusing a pre-fix sidecar (`ensure_sidecar_reuse` + instant cancel)
2. Orphan picker from dead sidecar while new sidecar waited on different result file

After fixes, user should run `:TelescopeBridgeRestart` once, reload embedded config, then test.

## Recommended test procedure

1. `:TelescopeBridgeRestart`
2. `:TelescopeBridgeLogClear`
3. Reload embedded nvim (`<leader>rr` or restart extension)
4. `:TelescopeBridgeStatus` → expect `ready_version: 3`, `bridge_version: 3` after first pick
5. `<leader><leader>` → pick file in **Telescope Bridge** terminal
6. Confirm file opens in VSCode editor
7. `<leader><leader>` again → should `ensure_sidecar_reuse` and still work
8. `:TelescopeBridgeLogTail 40` if anything fails

## Open work / next steps

### P0 — confirm happy path works

Run the test procedure above. If still broken, capture full log from `log_cleared` through one pick attempt.

### P1 — robustness

- [ ] **Focus terminal before picker**: sidecar may open picker without terminal focus; user picks in wrong window
- [ ] **Single-flight queue** instead of hard `run_picker_busy` reject
- [ ] **Don't panel_restore on cancel** until sidecar confirms no active prompts (race with false cancel)
- [ ] **Kill by socket path** fallback when `.ready` missing but process alive (`pkill -f vscode-telescope.sock`)
- [ ] **Integration tests** that mock filesystem RPC (current `test.lua` is minimal)

### P2 — feature parity with native config

Native `plugins.lua` has additional pickers not yet bridged:

- LSP pickers (`lsp_*`, `<leader>js` etc. in native)
- Buffer picker (`<leader>k` in native → `builtin.buffers`)
- Git/branches, diagnostics, etc.

Decide per-picker: bridge to sidecar vs keep workbench commands in `config.lua`.

### P3 — UX polish

- [ ] Pre-fill `cwd` from VSCode workspace root explicitly in request JSON
- [ ] Pass VSCode active file reliably for `current_buffer_fuzzy_find`
- [ ] Horizontal split: verify `vscode_actions` `viewColumn: beside` behavior
- [ ] Help tags / man_pages: may need path handling unlike file paths
- [ ] `help_tags` picker result may use different entry fields — verify `entry_path()`

### P4 — cleanup

- [ ] Turn off `vim.g.vscode_telescope_debug` by default once stable
- [ ] Remove duplicate `local M = {}` in `multigrep.lua`
- [ ] Document in user-facing README (optional; user didn't want unsolicited docs elsewhere)

## Editing checklist for agents

When changing sidecar behavior:

1. Bump `paths.BRIDGE_VERSION`
2. Update this handoff if protocol changes
3. Test both **spawn** and **reuse** paths
4. Test `<leader>jj` nested picker → sub-picker transition
5. Check log for `write_result` before `finish`
6. Run `:TelescopeBridgeRestart` after pulling sidecar changes (or rely on version gate)

When changing keymaps:

- VSCode branch: `plugins/vscode-telescope/init.lua`
- Native branch: `plugins.lua` (telescope spec, `cond = not is_vscode`)

When changing telescope defaults:

- Shared: `plugins/telescope/setup.lua`
- Sidecar loads this via `ensure_loaded()` in `sidecar.start()`

## Dependencies

- **vscode-neovim** with `require('vscode')` API
- **telescope.nvim** + **plenary.nvim** (via lazy in `plugins.lua`)
- **ripgrep** / **fd** for finders
- Neovim **0.12.x** (user on nix: `neovim-unwrapped-0.12.2`)
- VSCode terminal named **"Telescope Bridge"**

## Related native config (reference)

`plugins.lua` telescope keymaps for parity target:

```lua
<leader><leader>  find_files
<leader>jf        current_buffer_fuzzy_find
<leader>jg        multigrep
<leader>jp        pickers
<leader>jv        resume
<leader>jj        builtin (telescope menu)
<leader>jh        help_tags
<leader>js/ja/jc  LSP symbols
<leader>k         buffers
```

## Quick debug snippets

```vim
" Embedded
:lua print(require('plugins.vscode-telescope.rpc').ping())
:lua print(vim.inspect({
  version = require('plugins.vscode-telescope.rpc').ready_version(),
  expected = require('plugins.vscode-telescope.paths').BRIDGE_VERSION,
}))

" Sidecar terminal (if you can run ex commands there)
:lua print(vim.inspect(require('telescope.state').get_existing_prompt_bufnrs()))
```

## Contact / context

- User repo: `/Users/mattgmak/NixConfig`
- Primary workspace tested: `/Users/mattgmak/NixConfig`
- User wants **pure lua** in nvim config, no custom VSCode extension
- Prior approach used find-it-faster + workbench commands; this bridge replaces telescope-tier UX only
