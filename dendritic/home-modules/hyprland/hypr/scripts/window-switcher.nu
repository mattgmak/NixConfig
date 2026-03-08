#! /usr/bin/env nu

let clients = hyprctl clients -j | from json
let active_client = hyprctl activewindow -j | from json

let clients_without_active = $clients | where address != $active_client.address | sort-by focusHistoryID
if ($clients_without_active | is-empty) {
  exit 0
}

let lines = $clients_without_active | each {|client| $"[($client.workspace.name)] ($client.title) ($client.class)"}
let numbered_lines = ($lines | enumerate | each {|line| $"($line.index)\t($line.item)"})

let menu_file = (mktemp | str trim)
let result_file = (mktemp | str trim)
$numbered_lines | str join "\n" | save -f $menu_file

^ghostty --font-size=18  --title=window-switcher -e sh -lc $"cat '($menu_file)' | fzf --layout=reverse --delimiter '\t' --cycle --with-nth 2.. > '($result_file)'"

rm $menu_file
let selected = (open $result_file)

rm $result_file
if ($selected | is-empty) {
  exit 0
}

let selected_index = ($selected | split row "\t" | first | into int)
let client = ($clients_without_active | get $selected_index)
let selected_client_address = $client.address | into string
hyprctl dispatch focuswindow $"address:($selected_client_address)"
