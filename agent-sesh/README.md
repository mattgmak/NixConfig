# agent-sesh

## Locked spec (from grill-me)

| Decision | Choice |
|----------|--------|
| Stack | **Go + Bubble Tea** (bubbletea, bubbles, lipgloss) |
| Trigger | **`prefix-a`** via `tmux display-popup` (90% × 90%) |
| Data source (v1) | **pi-agent-sesh extension** → `~/.local/state/agent-sesh/sessions.json` |
| Preview | **`tmux capture-pane`** scrollback in right panel |
| Registry | Pi extension **explicitly registers** on session start/end |
| Status model | **4-state** (`idle`, `working`, `tool_call`, `waiting`) + tool name |
| Actions | sesh-like: Enter attach, `ctrl-x` kill pane, `ctrl-X` kill session, `ctrl-t` new window, `/` filter, `ctrl-r` rename (stub) |
| Layout | Standalone flake in `agent-sesh/` with bundled `pi-agent-sesh` extension |

## Related projects

- [sesh](https://github.com/joshmedeski/sesh) — Go tmux session manager; inspiration for picker UX and HM integration (`programs.sesh.tmuxKey = "g"` in this repo)
- [opensessions](https://github.com/Ataraxy-Labs/opensessions) — TypeScript tmux sidebar + HTTP API for multi-agent status; future merge target for non-pi agents
- herdr — future status backend (not wired in v1)

## Layout

```
agent-sesh/
  flake.nix
  cmd/agent-sesh/main.go
  internal/
    picker/     # Bubble Tea UI
    registry/   # sessions.json reader
    tmux/       # capture-pane + management cmds
  plugin/agent-sesh.tmux
  extensions/pi-agent-sesh/
```

## Registry format

```json
{
  "version": 1,
  "sessions": [
    {
      "id": "pi-session-uuid",
      "tmux_target": "nix:0.0",
      "cwd": "/Users/you/NixConfig",
      "branch": "main",
      "title": "agent-sesh specs",
      "status": "tool_call",
      "tool_name": "Shell: go mod tidy",
      "model": "claude-sonnet-4",
      "agent": "pi",
      "updated_at": "2026-07-31T03:00:00.000Z"
    }
  ]
}
```

## Integration (NixConfig)

Wired in this repo:

- `flake.nix` — `inputs.agent-sesh.url = "path:./agent-sesh"`
- `dendritic/home-modules/tmux.nix` — `programs.agent-sesh.enable = true` (`prefix-a`)
- `dendritic/home-modules/pi-coding-agent/extensions/pi-agent-sesh` — symlink → `agent-sesh/extensions/pi-agent-sesh/`

**Before first `nix build`**, track the subproject in git (Nix path flakes require it):

```bash
git add agent-sesh/
nix build ./agent-sesh#agent-sesh  # copy vendorHash from error into flake.nix
```

**Spawn a sibling pi pane for Go work** (run from your tmux session):

```bash
tmux split-window -h -c ~/NixConfig/agent-sesh \
  'pi "Implement agent-sesh Go picker — see README.md"'
```

## Nix

```bash
# from repo root
nix build ./agent-sesh
nix run ./agent-sesh -- pick
```

Home Manager module (after wiring root flake input):

```nix
programs.agent-sesh.enable = true;
programs.agent-sesh.tmuxKey = "a";
```

## Pi extension

Copy or symlink `extensions/pi-agent-sesh` into your pi extensions path, or vendor from this subproject.

The extension writes the registry file and should be wired to real pi lifecycle events (`session:start`, `session:end`, tool/status hooks). The scaffold uses placeholder `pi.on(...)` handlers — confirm against the pi extension API in your pi version.

## Tmux

Default bind (via plugin):

```
prefix-a  →  display-popup  →  agent-sesh pick
```

## Dev

```bash
cd agent-sesh
go mod tidy
go run ./cmd/agent-sesh
```

### Debug CLI

After rebuilding, inspect live registry/tmux state:

```bash
agent-sesh debug registry    # raw sessions.json
agent-sesh debug validate    # sanitize report (kept vs pruned)
agent-sesh debug panes       # registry rows vs live tmux panes
agent-sesh debug discover    # pi panes missing from registry
agent-sesh debug pane %0     # one pane snapshot (JSON)
```

## Roadmap

1. Wire pi-agent-sesh to real pi extension hooks
2. `go mod vendor` + pin `vendorHash` in flake
3. Root flake input + `programs.agent-sesh.enable` in `dendritic/home-modules/tmux.nix`
4. Merge opensessions/herdr status for non-pi agents
5. Implement `ctrl-r` rename-session prompt
