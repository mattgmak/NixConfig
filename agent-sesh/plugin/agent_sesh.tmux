#!/usr/bin/env bash

# agent-sesh tmux plugin entrypoint.
# Home Manager / Nix sets @agent-sesh-bin to the store path of the CLI.
# mkTmuxPlugin expects rtpFilePath agent_sesh.tmux (hyphens → underscores).

bind_key="@agent-sesh-bind"
bind_default="a"
table_key="@agent-sesh-table"
table_default="prefix"
popup_width="@agent-sesh-popup-width"
popup_width_default="90%"
popup_height="@agent-sesh-popup-height"
popup_height_default="90%"
mode_key="@agent-sesh-mode"
mode_default="tui"

agent_sesh_bin="@agent-sesh-bin"
agent_sesh_bin_default="agent-sesh"

resolved_bind="$(tmux show-option -gvq "$bind_key" 2>/dev/null || echo "$bind_default")"
resolved_table="$(tmux show-option -gvq "$table_key" 2>/dev/null || echo "$table_default")"
resolved_width="$(tmux show-option -gvq "$popup_width" 2>/dev/null || echo "$popup_width_default")"
resolved_height="$(tmux show-option -gvq "$popup_height" 2>/dev/null || echo "$popup_height_default")"
resolved_mode="$(tmux show-option -gvq "$mode_key" 2>/dev/null || echo "$mode_default")"
resolved_bin="$(tmux show-option -gvq "$agent_sesh_bin" 2>/dev/null || echo "$agent_sesh_bin_default")"

if [ "$resolved_mode" = "fzf" ]; then
  tmux bind-key -N "agent-sesh: picker (fzf)" -T "$resolved_table" "$resolved_bind" \
    run-shell "\"$resolved_bin\" fzf"
else
  tmux bind-key -N "agent-sesh: picker" -T "$resolved_table" "$resolved_bind" \
    run-shell "tmux display-popup -E -w \"$resolved_width\" -h \"$resolved_height\" \"$resolved_bin\""
fi
