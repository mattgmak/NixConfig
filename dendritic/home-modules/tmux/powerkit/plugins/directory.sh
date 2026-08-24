#!/usr/bin/env bash
# Plugin: directory
# Description: Current pane working directory (basename) — tmux format-native

POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
. "${POWERKIT_ROOT}/src/contract/plugin_contract.sh"

plugin_get_metadata() {
  metadata_set "id" "directory"
  metadata_set "name" "Directory"
  metadata_set "description" "Current pane working directory"
}

plugin_declare_options() {
  declare_option "icon" "icon" $'\U000F0153' "Directory icon"
  declare_option "cache_ttl" "number" "86400" "Cache duration in seconds"
  declare_option "max_length" "number" "24" "Max cwd chars before ellipsis truncation"
  declare_option "ellipsis" "string" $'…' "Truncation marker when cwd exceeds max_length"
}

plugin_get_content_type() { printf 'static'; }
plugin_get_presence() { printf 'always'; }
plugin_get_state() { printf 'active'; }
plugin_get_health() { printf 'ok'; }

# Live tmux expansion — no collect subprocess
plugin_collect() { return 0; }

plugin_render() {
  local max_len ellipsis
  max_len=$(get_option "max_length")
  ellipsis=$(get_option "ellipsis")
  if [[ -z "$max_len" || "$max_len" -le 0 ]]; then
    printf '%s' '#{b:pane_current_path}'
    return
  fi
  # tmux #{=/N/marker:#{b:path}} — nested basename then width-truncate with marker
  printf '#{=/%s/%s:#{b:pane_current_path}}' "$max_len" "$ellipsis"
}

plugin_get_icon() {
  get_option "icon"
}
