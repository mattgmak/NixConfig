#!/usr/bin/env bash
# Plugin: directory
# Description: Current pane working directory (basename)

POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
. "${POWERKIT_ROOT}/src/contract/plugin_contract.sh"

plugin_get_metadata() {
  metadata_set "id" "directory"
  metadata_set "name" "Directory"
  metadata_set "description" "Current pane working directory"
}

plugin_declare_options() {
  declare_option "icon" "icon" $'\U000F0153' "Directory icon"
  declare_option "cache_ttl" "number" "1" "Cache duration in seconds"
}

plugin_get_content_type() { printf 'dynamic'; }
plugin_get_presence() { printf 'always'; }
plugin_get_state() { printf 'active'; }
plugin_get_health() { printf 'info'; }

plugin_collect() {
  local path
  path=$(tmux display-message -p '#{b:pane_current_path}' 2>/dev/null || true)
  plugin_data_set "path" "$path"
}

plugin_render() {
  local path
  path=$(plugin_data_get "path")
  [[ -n "$path" ]] && printf ' %s' "$path"
}

plugin_get_icon() {
  get_option "icon"
}
