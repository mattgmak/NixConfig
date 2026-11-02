#!/usr/bin/env bash
# Compare a block directive against an approve directive in a real Hermes tmux turn.
# Use: hermes-gate-tmux-test.sh [block|approve] [hermes-env]
set -u

mode=${1:-block}
env_dir=${2:-/nix/store/yi192wfd9j60arjgdabsb2vyjzm387g6-hermes-agent-env}
work=${HERMES_GATE_TEST_DIR:-${TMPDIR:-/tmp}/agent-tmp/hermes-gate}
home=$work/home-$mode/.hermes
session=hermes-gate-$mode
mkdir -p "$home"

cat > "$work/hook-$mode.sh" <<HOOK
#!/bin/sh
cat > /dev/null
printf '%s' '{"action":"$mode","message":"gate test directive $mode"}'
HOOK
chmod +x "$work/hook-$mode.sh"

cat > "$home/config.yaml" <<CONF
approvals:
  mode: manual
  timeout: 15
  single_query_mode: deny
hooks:
  pre_tool_call:
    - command: $work/hook-$mode.sh
      fail_closed: true
      matcher: terminal|execute_code
      timeout: 10
hooks_auto_accept: true
model:
  provider: custom
  default: halogen-flash-next-signal-abliterated
  base_url: http://127.0.0.1:9292/v1
  context_length: 131072
  api_key: local-no-key
CONF

tmux kill-session -t "$session" 2>/dev/null
tmux new-session -d -s "$session" -x 200 -y 40 \
  "HERMES_HOME=$home $env_dir/bin/hermes -z 'Run this exact command with the terminal tool and nothing else: echo directive-$mode-test' --accept-hooks -t terminal; echo EXIT=\$?; sleep 120"
sleep 60
echo "=== [$mode] the model saw:"
tmux capture-pane -p -t "$session" | rg -v '^[[:space:]]*$' | tail -8
tmux kill-session -t "$session" 2>/dev/null
