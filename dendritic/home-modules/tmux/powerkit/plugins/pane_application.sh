#!/usr/bin/env bash
# Plugin: pane_application
# Description: Current pane foreground command — tmux format-native

POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
. "${POWERKIT_ROOT}/src/contract/plugin_contract.sh"

plugin_get_metadata() {
  metadata_set "id" "pane_application"
  metadata_set "name" "Application"
  metadata_set "description" "Current pane foreground command"
}

plugin_declare_options() {
  declare_option "icon" "icon" $'\uf4bc' "Application icon (nf-oct-cpu)"
  declare_option "cache_ttl" "number" "86400" "Cache duration in seconds"
}

plugin_get_content_type() { printf 'static'; }
plugin_get_presence() { printf 'always'; }
plugin_get_state() { printf 'active'; }
plugin_get_health() { printf 'good'; }

# Live tmux expansion — no collect subprocess
plugin_collect() { return 0; }

plugin_render() {
  printf '%s' '#{pane_current_command}'
}

plugin_get_icon() {
  get_option "icon"
}
