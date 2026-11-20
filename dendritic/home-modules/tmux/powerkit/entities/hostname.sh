#!/usr/bin/env bash
# =============================================================================
# PowerKit Entity: hostname
# Description: Left-side hostname pill — single pill, OS icon + short hostname
# =============================================================================
# Renders one pill in the per-host color (or grey fallback) so the OS icon and
# hostname share a background, then the compositor places it before the session
# pill.
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
    local colors content_bg content_fg icon host body bg fg

    colors=$(resolve_plugin_colors_full "active" "ok" "local" "0")
    read -r content_bg content_fg _icon_bg _icon_fg <<<"$colors"

    bg=$(get_tmux_option "@powerkit_hostname_bg" "")
    fg=$(get_tmux_option "@powerkit_hostname_fg" "")
    [[ -n "$bg" ]] && content_bg="$bg"
    [[ -n "$fg" ]] && content_fg="$fg"

    icon=$(get_os_icon)
    case "$(get_tmux_option "@powerkit_plugin_hostname_format" "short")" in
        full) host=$(get_hostname_full) ;;
        *) host=$(get_hostname) ;;
    esac
    host="${host//#/##}"

    body="#[$( [[ -n "$content_fg" ]] && printf 'fg=%s,' "$content_fg" )bg=${content_bg}] ${icon} ${host} "

    _HOSTNAME_PILL_BG="$content_bg"
    _HOSTNAME_PILL_FIRST_BG="$content_bg"
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
