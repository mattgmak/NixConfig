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
}

plugin_get_content_type() { printf 'static'; }
plugin_get_presence() { printf 'always'; }
plugin_get_state() { printf 'active'; }
plugin_get_health() { printf 'ok'; }

# Live tmux expansion — no collect subprocess
plugin_collect() { return 0; }

plugin_render() {
  printf '%s' '#{b:pane_current_path}'
}

plugin_get_icon() {
  get_option "icon"
}
