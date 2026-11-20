#!/usr/bin/env bash
# =============================================================================
# PowerKit Entity: hostname
# Description: Left-side hostname pill — dynamic OS icon + short hostname
# =============================================================================
# Mirrors the hostname plugin's two-layer segment (icon section + internal
# curve + content section) so the pill looks unchanged, then renders it as a
# left entity so the compositor places it before the session pill.
# =============================================================================

POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)}"
. "${POWERKIT_ROOT}/src/core/guard.sh"
source_guard "entity_hostname" && return 0

. "${POWERKIT_ROOT}/src/core/defaults.sh"
. "${POWERKIT_ROOT}/src/core/options.sh"
. "${POWERKIT_ROOT}/src/renderer/color_resolver.sh"
. "${POWERKIT_ROOT}/src/renderer/separator.sh"
. "${POWERKIT_ROOT}/src/utils/platform.sh"

declare -g _HOSTNAME_PILL_BG=""
declare -g _HOSTNAME_PILL_FIRST_BG=""
declare -g _HOSTNAME_PILL_BODY=""

_hostname_fill() {
    local colors content_bg content_fg icon_bg icon_fg icon host sep body

    colors=$(resolve_plugin_colors_full "active" "ok" "local" "0")
    read -r content_bg content_fg icon_bg icon_fg <<<"$colors"

    icon=$(get_os_icon)
    case "$(get_tmux_option "@powerkit_plugin_hostname_format" "short")" in
        full) host=$(get_hostname_full) ;;
        *) host=$(get_hostname) ;;
    esac
    host="${host//#/##}"
    sep=$(get_right_separator)

    body="#[fg=${icon_fg},bg=${icon_bg}]${icon} "
    [[ -n "$sep" ]] && body+="#[fg=${icon_bg},bg=${content_bg}]${sep}"
    body+="#[fg=${content_fg},bg=${content_bg}] ${host} "

    _HOSTNAME_PILL_BG="$content_bg"
    _HOSTNAME_PILL_FIRST_BG="$icon_bg"
    _HOSTNAME_PILL_BODY="$body"
}

hostname_get_bg() {
    [[ -z "$_HOSTNAME_PILL_BG" ]] && _hostname_fill
    printf '%s' "$_HOSTNAME_PILL_BG"
}

hostname_get_first_bg() {
    [[ -z "$_HOSTNAME_PILL_FIRST_BG" ]] && _hostname_fill
    printf '%s' "$_HOSTNAME_PILL_FIRST_BG"
}

hostname_get_last_bg() {
    hostname_get_bg
}

hostname_configure() {
    :
}

# Render the pill content; the compositor adds the outer separators.
# Usage: hostname_render [side]
hostname_render() {
    [[ -z "$_HOSTNAME_PILL_BODY" ]] && _hostname_fill
    printf '%s' "$_HOSTNAME_PILL_BODY"
}
