#!/usr/bin/env bash
set -euo pipefail

dir="$HOME/Pictures/Screenshots"
file="$dir/screenshot-$(date +%Y%m%d_%H%M%S).png"
mkdir -p "$dir"

border="$(hyprctl getoption general:border_size -j | jq -r '.int')"
rounding="$(hyprctl getoption decoration:rounding -j | jq -r '.int')"
radius=$((border + rounding))

# Snap boxes for slurp. Outputs first, then windows on visible workspaces.
# Hyprland reports width and height untransformed, so a rotated display needs
# the pair swapped. Window rects exclude the border, so grow them by it.
outs="$(hyprctl monitors -j | jq -r '.[] | "\(.x),\(.y) \(if (.transform % 2) == 1 then "\(.height)x\(.width)" else "\(.width)x\(.height)" end)"')"
visible="$(hyprctl monitors -j | jq -c '[.[] | if .specialWorkspace.name != "" then .specialWorkspace.id else .activeWorkspace.id end]')"
wins="$(hyprctl clients -j | jq -r --argjson visible "$visible" --argjson b "$border" '.[] | select(.mapped and (.workspace.id as $id | $visible | index($id))) | "\(.at[0] - $b),\(.at[1] - $b) \(.size[0] + 2 * $b)x\(.size[1] + 2 * $b)"')"

# hyprpicker -r paints a frozen copy of each display in a layer surface, so the
# region select sees still frames. It must stay alive during grim, or the
# screen repaints mid capture.
hyprpicker -r -z -q >/dev/null 2>&1 &
picker=$!
trap 'kill "$picker" 2>/dev/null || true' EXIT

sleep 0.2
geometry="$(printf '%s\n%s\n' "$outs" "$wins" | slurp)" || exit 0

grim -g "$geometry" "$file"

# A window grab keeps the desktop in its four rounded corners. Free regions and
# whole outputs stay square.
snapped=false
while IFS= read -r box; do
	if [ -n "$box" ] && [ "$box" = "$geometry" ]; then
		snapped=true
		break
	fi
done <<<"$wins"

if [ "$snapped" = true ] && [ "$radius" -gt 0 ]; then
	w="$(magick identify -format %w "$file")"
	h="$(magick identify -format %h "$file")"
	masked="$(mktemp --suffix=.png)"
	magick "$file" -alpha set \( -size "${w}x${h}" xc:none -fill white -draw "roundrectangle 0,0,$((w - 1)),$((h - 1)),$radius,$radius" \) -compose DstIn -composite "$masked"
	mv "$masked" "$file"
fi

kill "$picker" 2>/dev/null || true

wl-copy --type image/png <"$file"

reply="$(notify-send -a caelestia-cli -i "$file" -h "STRING:image-path:$file" -p -A edit=Edit "Screenshot saved" "$file")" || true
id="${reply%%$'\n'*}"
action="${reply##*$'\n'}"

if [ "$action" = "edit" ]; then
	gdbus call --session --dest org.freedesktop.Notifications --object-path /org/freedesktop/Notifications --method org.freedesktop.Notifications.CloseNotification "$id" >/dev/null 2>&1 || true
	swappy -f "$file"
fi
