#!/usr/bin/env python3
"""Powerkit patches: layout, render cache TTL, session mode backgrounds."""

from __future__ import annotations

import pathlib
import sys


def patch_compositor(path: pathlib.Path) -> None:
    text = path.read_text()

    bridge_fn = """
# Session → windows: rounded exit only (no gap; first window handles entry)
# Usage: _build_session_windows_bridge
_build_session_windows_bridge() {
    local session_bg sep_char
    session_bg=$(session_get_last_bg)

    sep_char=$(get_edge_right_separator)
    [[ -z "$sep_char" ]] && sep_char=$(get_right_separator)
    if [[ -n "$sep_char" ]]; then
        printf '#[fg=%s,bg=%s]%s' "$session_bg" "$session_bg" "$sep_char"
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

    helper = """# Escape commas inside tmux format strings used as #{?} branches
_escape_tmux_format_commas() {
    local s="$1"
    s="${s//,/#,}"
    printf '%s' "$s"
}

"""
    anchor = "# Build window-to-window separator"
    if "_escape_tmux_format_commas()" not in text:
        if anchor not in text:
            raise SystemExit(f"windows comma escape inject: anchor not found in {path}")
        text = text.replace(anchor, helper + anchor, 1)

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
        # First window: rounded entry from session; others: rounded inter-window join
        local session_bg first rest
        session_bg=$(session_get_last_bg)
        if [[ "$side" == "left" || "$side" == "center" ]]; then
            first=$(_escape_tmux_format_commas "$(printf '#[fg=%s#,bg=%s]%s' "$session_bg" "$index_bg" "$_W_EDGE_SEP_CHAR")")
            rest=$(_escape_tmux_format_commas "$(printf '#[fg=%s#,bg=%s]%s' "$previous_bg" "$index_bg" "$_W_SEP_CHAR")")
        else
            first=$(_escape_tmux_format_commas "$(printf '#[fg=%s#,bg=%s]%s' "$index_bg" "$session_bg" "$_W_EDGE_SEP_CHAR")")
            rest=$(_escape_tmux_format_commas "$(printf '#[fg=%s#,bg=%s]%s' "$index_bg" "$previous_bg" "$_W_SEP_CHAR")")
        fi
        printf '#{?window_start_flag,%s,%s}' "$first" "$rest"
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
        if old not in text:
            raise SystemExit(f"windows trim trailing space: pattern not found in {path}")
        text = text.replace(old, new, 1)
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
    old = """    printf '#{?client_prefix,(prefix) ,#{?pane_in_mode,#{?search_present,(search) ,(copy) },#{?command_prompt,(command) ,}}}'
"""
    new = """    # prefix mode: bg only, no "(prefix)" label
    printf '#{?pane_in_mode,#{?search_present,(search) ,(copy) },#{?command_prompt,(command) ,}}'
"""
    if old not in text:
        raise SystemExit(f"session mode text patch: pattern not found in {path}")
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


def main() -> None:
    root = pathlib.Path(sys.argv[1])
    patch_compositor(root / "src/renderer/compositor.sh")
    patch_windows_group_edges(root / "src/renderer/entities/windows.sh")
    patch_windows_trim_content_trailing_space(root / "src/renderer/entities/windows.sh")
    patch_session_copy_icon_default(root / "src/renderer/entities/session.sh")
    patch_session_mode_text_no_prefix(root / "src/renderer/entities/session.sh")
    patch_session_mode_bg(root / "src/renderer/entities/session.sh")
    patch_render_cache(root / "bin/powerkit-render")


if __name__ == "__main__":
    main()
