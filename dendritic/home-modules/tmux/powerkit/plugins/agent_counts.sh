#!/usr/bin/env bash
# Plugin: agent_counts
# Description: Agent session counts by attention/active/idle status

POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
. "${POWERKIT_ROOT}/src/contract/plugin_contract.sh"

plugin_get_metadata() {
  metadata_set "id" "agent_counts"
  metadata_set "name" "Agent counts"
  metadata_set "description" "Running agent sessions by status category"
}

plugin_declare_options() {
  declare_option "icon" "icon" $'\U000F06A9' "Agent icon (nf-md-robot)"
  declare_option "bin" "string" "agent-sesh" "agent-sesh CLI path"
  declare_option "cache_ttl" "number" "0" "Cache duration in seconds (0 = always fresh)"
}

plugin_get_content_type() { printf 'dynamic'; }
plugin_get_presence() { printf 'always'; }
plugin_get_state() { printf 'active'; }
plugin_get_health() { printf 'warning'; }

_resolve_bin() {
  local configured fallback
  configured=$(tmux show-option -gvq "@agent-sesh-bin" 2>/dev/null || true)
  fallback=$(get_option "bin")
  if [[ -n "$configured" && "$configured" != "@agent-sesh-bin" ]]; then
    printf '%s' "$configured"
  else
    printf '%s' "$fallback"
  fi
}

plugin_collect() {
  local bin counts
  bin=$(_resolve_bin)
  counts=$("$bin" counts 2>/dev/null) || counts=""
  plugin_data_set "counts" "$counts"
}

plugin_render() {
  plugin_data_get "counts"
}

plugin_get_icon() {
  get_option "icon"
}
