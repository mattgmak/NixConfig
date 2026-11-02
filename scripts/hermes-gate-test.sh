#!/usr/bin/env bash
# Spawn one Hermes turn that must call the deploy switch, then show what the gate saw.
# Use: hermes-gate-test.sh [gate-path] [hermes-env]
set -u

gate=${1:-/run/current-system/sw/bin/ramsay-gate}
env_dir=${2:-/nix/store/yi192wfd9j60arjgdabsb2vyjzm387g6-hermes-agent-env}
work=${HERMES_GATE_TEST_DIR:-${TMPDIR:-/tmp}/agent-tmp/hermes-gate}
home=$work/home/.hermes
mkdir -p "$home"

cat > "$work/hook.sh" <<HOOK
#!/bin/sh
log=$work/payload.log
payload=\$(cat 2>/dev/null || true)
out=\$(printf '%s' "\$payload" | $gate)
printf '=== %s rc=%s\nIN : %s\nOUT: %s\n' "\$(date -u +%H:%M:%SZ)" "\$?" "\$payload" "\$out" >> "\$log" 2>/dev/null || true
printf '%s' "\$out"
HOOK
chmod +x "$work/hook.sh"

cat > "$home/config.yaml" <<CONF
approvals:
  mode: manual
  timeout: 20
  cron_mode: deny
  single_query_mode: deny
  unattended_mode: deny
hooks:
  pre_tool_call:
    - command: $work/hook.sh
      fail_closed: true
      matcher: terminal|execute_code
      timeout: 15
hooks_auto_accept: true
security:
  approval:
    transport: builtin
    transport_fallback: deny
model:
  provider: custom
  default: halogen-flash-next-signal-abliterated
  base_url: http://127.0.0.1:9292/v1
  context_length: 131072
  api_key: local-no-key
CONF

rm -f "$work/payload.log"
echo "gate: $gate"
echo "home: $home"
HERMES_HOME=$home timeout 600 "$env_dir/bin/hermes" \
  -z "Run this exact command with the terminal tool and nothing else: sudo /run/current-system/sw/bin/ramsay-deploy-switch" \
  --accept-hooks -t terminal 2>&1 | tail -20
echo "=== gate log:"
cat "$work/payload.log" 2>/dev/null
