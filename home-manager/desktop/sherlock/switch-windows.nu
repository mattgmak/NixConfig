#! /usr/bin/env nu


# Get Hyprland window data and transform it for Sherlock
let raw_json = hyprctl clients -j | from json

# Filter out windows that are not useful for switching (unmapped, etc.)
let filtered_windows = $raw_json | where mapped == true | where hidden == false

# Transform each window into Sherlock's expected format
let sherlock_elements = $filtered_windows | each { |window|
    let workspace_info = if ($window.workspace.name != null) { $"Workspace ($window.workspace.name)" } else { "Unknown Workspace" }
    let window_state = if $window.floating { "Floating" } else { "Tiled" }
    let size_info = $"($window.size.0)x($window.size.1)"

    # Create description with useful window information
    let description = $"($window.class) • ($workspace_info) • ($window_state) • ($size_info)"

    # Determine icon based on class
    let icon = match $window.class {
        "vesktop" => "discord",
        _ => $window.class
    }

    {
        "title": $window.title,
        "description": $description,
        "icon": $icon,
        "icon_size": 40,
        "result": "title",
        "method": "print",
        "field": "address",
        "hidden": {
            "address": $window.address,
        },
        "exit": true
    }
}

# Output the transformed data as JSON for Sherlock
let sherlock_json = {
  "settings": [],
  "elements": $sherlock_elements
}
let data_to_pipe_to_sherlock = $sherlock_json | to json
print $data_to_pipe_to_sherlock
let selected_window = $data_to_pipe_to_sherlock | sherlock
print $selected_window

# Check if we're being called with a window address to focus
if ($selected_window | is-not-empty) {
    # Focus the window using Hyprland's dispatch command
    hyprctl dispatch focuswindow $"address:($selected_window)"
}
