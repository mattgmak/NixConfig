#!/usr/bin/env python3
"""Powerkit patches: pill-group caps, session mode, render cache."""

from __future__ import annotations

import pathlib
import sys


def patch_compositor(path: pathlib.Path) -> None:
    text = path.read_text()

    bridge_fn = """
# Session pill closes into gap (fg=session, bg=default). Windows open after.
# Usage: _build_session_windows_bridge
_build_session_windows_bridge() {
    local session_bg sep_char
    session_bg=$(session_get_last_bg)

    sep_char=$(get_edge_right_separator)
    [[ -z "$sep_char" ]] && sep_char=$(get_right_separator)
    if [[ -n "$sep_char" ]]; then
        printf '#[fg=%s,bg=default]%s ' "$session_bg" "$sep_char"
    fi
}

"""
    anchor = "# Usage: _build_window_spacing_gap\n_build_window_spacing_gap() {"
    if bridge_fn.strip() not in text:
        if anchor not in text:
            raise SystemExit(f"compositor bridge inject: anchor not found in {path}")
        text = text.replace(anchor, bridge_fn + anchor, 1)

    old = '            left_content+=$(_build_inter_entity_separator "$last_left" "windows" "left")'
    new = """            if [[ "$last_left" == "session" ]]; then
                left_content+=$(_build_session_windows_bridge)
            else
                left_content+=$(_build_inter_entity_separator "$last_left" "windows" "left")
            fi"""
    if old not in text:
        raise SystemExit(f"compositor patch: pattern not found in {path}")
    path.write_text(text.replace(old, new, 1))


def patch_windows_group_edges(path: pathlib.Path) -> None:
    text = path.read_text()
    old = """    else
        # For all sides, first window doesn't need edge separator (handled by compositor)
        # Only add inter-window separators (window 2+)
        if [[ "$side" == "left" || "$side" == "center" ]]; then
            printf '#[fg=%s,bg=%s]#{?window_start_flag,,%s}' "$previous_bg" "$index_bg" "$_W_SEP_CHAR"
        else
            # Right side: separator points left (◀)
            printf '#[fg=%s,bg=%s]#{?window_start_flag,,%s}' "$index_bg" "$previous_bg" "$_W_SEP_CHAR"
        fi
    fi
}"""
    new = """    else
        # First window: left pill cap from gap. Hex only inside #{?} (escaped comma).
        # Later windows: join previous → current. Style OUTSIDE #{?} — previous_bg
        # is nested #{m}/#{W}/#{?} and those commas must stay real.
        local left_cap
        left_cap=$(get_edge_left_separator)
        [[ -z "$left_cap" ]] && left_cap="$_W_EDGE_SEP_CHAR"
        if [[ "$side" == "left" || "$side" == "center" ]]; then
            printf '#{?window_start_flag,#[fg=%s#,bg=default]%s,}' "$index_bg" "$left_cap"
            printf '#[fg=%s,bg=%s]#{?window_start_flag,,%s}' "$previous_bg" "$index_bg" "$_W_SEP_CHAR"
        else
            printf '#{?window_start_flag,#[fg=%s#,bg=default]%s,}' "$index_bg" "$left_cap"
            printf '#[fg=%s,bg=%s]#{?window_start_flag,,%s}' "$index_bg" "$previous_bg" "$_W_SEP_CHAR"
        fi
    fi
}"""
    if old not in text:
        raise SystemExit(f"windows group edges patch: pattern not found in {path}")
    path.write_text(text.replace(old, new, 1))


def patch_windows_trim_content_trailing_space(path: pathlib.Path) -> None:
    text = path.read_text()
    replacements = [
        (
            'format+="#[fg=${content_fg},bg=${content_bg}${style_attr}] ${window_content} "',
            'format+="#[fg=${content_fg},bg=${content_bg}${style_attr}] ${window_content}"',
        ),
        (
            'format+="#[fg=${content_fg},bg=${content_bg}${style_attr}]${window_content} "',
            'format+="#[fg=${content_fg},bg=${content_bg}${style_attr}]${window_content}"',
        ),
        (
            'format+="#[fg=${content_fg},bg=${content_bg}${style_attr}] ${window_content} $(pane_sync_format)"',
            'format+="#[fg=${content_fg},bg=${content_bg}${style_attr}] ${window_content}$(pane_sync_format)"',
        ),
        (
            'format+="#[fg=${content_fg},bg=${content_bg}${style_attr}]${window_content} $(pane_sync_format)"',
            'format+="#[fg=${content_fg},bg=${content_bg}${style_attr}]${window_content}$(pane_sync_format)"',
        ),
    ]
    for old, new in replacements:
        if old in text:
            text = text.replace(old, new, 1)
        elif new not in text:
            raise SystemExit(f"windows trim trailing space: pattern not found in {path}")
    path.write_text(text)


def patch_session_copy_icon_default(path: pathlib.Path) -> None:
    text = path.read_text()
    old = 'icon_copy=$(get_tmux_option "@powerkit_session_copy_icon" "${POWERKIT_DEFAULT_SESSION_COPY_MODE_COLOR}")'
    new = 'icon_copy=$(get_tmux_option "@powerkit_session_copy_icon" "${POWERKIT_DEFAULT_SESSION_COPY_ICON}")'
    if old not in text:
        raise SystemExit(f"session copy icon default patch: pattern not found in {path}")
    path.write_text(text.replace(old, new, 1))


def patch_session_mode_text_no_prefix(path: pathlib.Path) -> None:
    text = path.read_text()
    new = """    # Mode = icon + bg only. No "(copy)" / "(search)" / "(command)" labels.
    printf ''
"""
    olds = [
        """    printf '#{?client_prefix,(prefix) ,#{?pane_in_mode,#{?search_present,(search) ,(copy) },#{?command_prompt,(command) ,}}}'
""",
        """    printf '#{?pane_in_mode,#{?search_present,(search) ,(copy) },#{?command_prompt,(command) ,}}'
""",
    ]
    for old in olds:
        if old in text:
            path.write_text(text.replace(old, new, 1))
            return
    if "Mode = icon + bg only" in text:
        return
    raise SystemExit(f"session mode text patch: pattern not found in {path}")


def patch_session_icon_all_modes(path: pathlib.Path) -> None:
    text = path.read_text()
    old = """_session_build_icon_condition() {
    local icon_normal icon_prefix icon_copy

    icon_normal=$(resolve_session_icon)
    icon_prefix=$(get_tmux_option "@powerkit_session_prefix_icon" "${POWERKIT_DEFAULT_SESSION_PREFIX_ICON}")
    icon_copy=$(get_tmux_option "@powerkit_session_copy_icon" "${POWERKIT_DEFAULT_SESSION_COPY_ICON}")

    _session_icon_has_content() {
        local val="$1"
        [[ -z "$val" ]] && return 1
        local _empty_cond_re="^#\\{\\?[0-9]+,,\\}$"
        [[ "$val" =~ $_empty_cond_re ]] && return 1
        return 0
    }
    _session_icon_has_content "$icon_prefix" && icon_prefix="${icon_prefix} "
    _session_icon_has_content "$icon_copy" && icon_copy="${icon_copy} "
    _session_icon_has_content "$icon_normal" && icon_normal="${icon_normal} "

    # Conditional: prefix mode -> prefix_icon, copy mode -> copy_icon, else -> normal_icon
    printf '#{?client_prefix,%s,#{?pane_in_mode,%s,%s}}' "$icon_prefix" "$icon_copy" "$icon_normal"
}
"""
    new = """_session_build_icon_condition() {
    local icon_normal icon_prefix icon_copy icon_search icon_command

    icon_normal=$(resolve_session_icon)
    icon_prefix=$(get_tmux_option "@powerkit_session_prefix_icon" "${POWERKIT_DEFAULT_SESSION_PREFIX_ICON}")
    icon_copy=$(get_tmux_option "@powerkit_session_copy_icon" "${POWERKIT_DEFAULT_SESSION_COPY_ICON}")
    icon_search=$(get_tmux_option "@powerkit_session_search_icon" $'\\uf002')
    icon_command=$(get_tmux_option "@powerkit_session_command_icon" $'\\uf120')

    _session_icon_has_content() {
        local val="$1"
        [[ -z "$val" ]] && return 1
        local _empty_cond_re="^#\\{\\?[0-9]+,,\\}$"
        [[ "$val" =~ $_empty_cond_re ]] && return 1
        return 0
    }
    _session_icon_has_content "$icon_prefix" && icon_prefix="${icon_prefix} "
    _session_icon_has_content "$icon_copy" && icon_copy="${icon_copy} "
    _session_icon_has_content "$icon_search" && icon_search="${icon_search} "
    _session_icon_has_content "$icon_command" && icon_command="${icon_command} "
    _session_icon_has_content "$icon_normal" && icon_normal="${icon_normal} "

    # prefix > search > copy > command > normal (matches _session_build_bg_condition)
    printf '#{?client_prefix,%s,#{?pane_in_mode,#{?search_present,%s,%s},#{?command_prompt,%s,%s}}}' \\
        "$icon_prefix" "$icon_search" "$icon_copy" "$icon_command" "$icon_normal"
}
"""
    if old not in text:
        raise SystemExit(f"session icon all modes patch: pattern not found in {path}")
    path.write_text(text.replace(old, new, 1))


def patch_session_mode_bg(path: pathlib.Path) -> None:
    text = path.read_text()
    old = """    local prefix_bg copy_bg normal_bg
    prefix_bg=$(resolve_color "$prefix_color_name")
    copy_bg=$(resolve_color "$copy_color_name")
    normal_bg=$(resolve_color "$normal_color_name")

    # Conditional: prefix mode -> prefix_bg, copy mode -> copy_bg, else -> normal_bg
    printf '#{?client_prefix,%s,#{?pane_in_mode,%s,%s}}' "$prefix_bg" "$copy_bg" "$normal_bg"
"""
    new = """    local prefix_bg copy_bg search_bg command_bg normal_bg
    prefix_bg=$(resolve_color "$prefix_color_name")
    copy_bg=$(resolve_color "$copy_color_name")
    search_bg=$(resolve_color "session-search-bg")
    command_bg=$(resolve_color "session-command-bg")
    normal_bg=$(resolve_color "$normal_color_name")

    # prefix > search > copy > command > normal (matches _session_build_mode_text)
    printf '#{?client_prefix,%s,#{?pane_in_mode,#{?search_present,%s,%s},#{?command_prompt,%s,%s}}}' \\
        "$prefix_bg" "$search_bg" "$copy_bg" "$command_bg" "$normal_bg"
"""
    if old not in text:
        raise SystemExit(f"session mode bg patch: pattern not found in {path}")
    path.write_text(text.replace(old, new, 1))


def patch_render_cache(path: pathlib.Path) -> None:
    text = path.read_text()
    old = "# TTL for render cache (matches status-interval)\n_RENDER_CACHE_TTL=5"
    new = "# TTL for render cache (follow status-interval)\n_RENDER_CACHE_TTL=$(get_tmux_option \"@powerkit_status_interval\" \"5\")"
    if old not in text:
        raise SystemExit(f"render cache patch: pattern not found in {path}")
    path.write_text(text.replace(old, new, 1))


def patch_plugin_text_contrast(path: pathlib.Path) -> None:
    text = path.read_text()
    old = """get_health_text_color() {
    local health="$1"
    local base_color="${_HEALTH_COLORS[$health]:-ok-base}"
    # Use -darker variant for text (better contrast)
    get_color "${base_color}-darker"
}"""
    new = """get_health_text_color() {
    local health="$1"
    local base_color="${_HEALTH_COLORS[$health]:-ok-base}"
    local variant
    variant=$(get_contrast_variant "$base_color")
    get_color "${base_color}-${variant}"
}"""
    if old not in text:
        raise SystemExit(f"plugin text contrast patch: pattern not found in {path}")
    path.write_text(text.replace(old, new, 1))


def patch_datetime_health(path: pathlib.Path) -> None:
    text = path.read_text()
    old = 'plugin_get_health() { printf \'ok\'; }'
    new = 'plugin_get_health() { printf \'info\'; }'
    if old not in text:
        raise SystemExit(f"datetime health patch: pattern not found in {path}")
    path.write_text(text.replace(old, new, 1))


def main() -> None:
    root = pathlib.Path(sys.argv[1])
    patch_compositor(root / "src/renderer/compositor.sh")
    patch_windows_group_edges(root / "src/renderer/entities/windows.sh")
    patch_windows_trim_content_trailing_space(root / "src/renderer/entities/windows.sh")
    patch_session_copy_icon_default(root / "src/renderer/entities/session.sh")
    patch_session_icon_all_modes(root / "src/renderer/entities/session.sh")
    patch_session_mode_text_no_prefix(root / "src/renderer/entities/session.sh")
    patch_session_mode_bg(root / "src/renderer/entities/session.sh")
    patch_render_cache(root / "bin/powerkit-render")
    patch_plugin_text_contrast(root / "src/core/color_palette.sh")
    patch_datetime_health(root / "src/plugins/datetime.sh")


if __name__ == "__main__":
    main()
