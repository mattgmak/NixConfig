-- Pull in the wezterm API
local wezterm = require("wezterm")
local act = wezterm.action
local config = wezterm.config_builder()

config.key_tables = wezterm.gui.default_key_tables()
-- Copy mode key bindings
table.insert(config.key_tables.copy_mode, {
    key = 'j',
    mods = 'NONE',
    action = act.CopyMode 'MoveUp'
})
table.insert(config.key_tables.copy_mode, {
    key = 'k',
    mods = 'NONE',
    action = act.CopyMode 'MoveDown'
})
table.insert(config.key_tables.copy_mode, {
    key = 'l',
    mods = 'NONE',
    action = act.CopyMode 'MoveLeft'
})
table.insert(config.key_tables.copy_mode, {
    key = ';',
    mods = 'NONE',
    action = act.CopyMode 'MoveRight'
})

-- tmux
config.leader = {
    key = 'b',
    mods = 'CTRL',
    timeout_milliseconds = 2000
}
config.keys = {{
    mods = "LEADER",
    key = "c",
    action = wezterm.action.SpawnTab "CurrentPaneDomain"
}, {
    mods = "LEADER",
    key = "x",
    action = wezterm.action.CloseCurrentPane {
        confirm = true
    }
}, {
    mods = "LEADER",
    key = "b",
    action = wezterm.action.ActivateTabRelative(-1)
}, {
    mods = "LEADER",
    key = "n",
    action = wezterm.action.ActivateTabRelative(1)
}, {
    mods = "LEADER",
    key = "|",
    action = wezterm.action.SplitHorizontal {
        domain = "CurrentPaneDomain"
    }
}, {
    mods = "LEADER",
    key = "-",
    action = wezterm.action.SplitVertical {
        domain = "CurrentPaneDomain"
    }
}, {
    mods = "LEADER",
    key = "l",
    action = wezterm.action.ActivatePaneDirection "Left"
}, {
    mods = "LEADER",
    key = "k",
    action = wezterm.action.ActivatePaneDirection "Down"
}, {
    mods = "LEADER",
    key = "j",
    action = wezterm.action.ActivatePaneDirection "Up"
}, {
    mods = "LEADER",
    key = ";",
    action = wezterm.action.ActivatePaneDirection "Right"
}, {
    mods = "LEADER",
    key = "LeftArrow",
    action = wezterm.action.AdjustPaneSize {"Left", 5}
}, {
    mods = "LEADER",
    key = "RightArrow",
    action = wezterm.action.AdjustPaneSize {"Right", 5}
}, {
    mods = "LEADER",
    key = "DownArrow",
    action = wezterm.action.AdjustPaneSize {"Down", 5}
}, {
    mods = "LEADER",
    key = "UpArrow",
    action = wezterm.action.AdjustPaneSize {"Up", 5}
}}

for i = 1, 9 do
    -- leader + number to activate that tab
    table.insert(config.keys, {
        key = tostring(i),
        mods = "LEADER",
        action = wezterm.action.ActivateTab(i - 1)
    })
end

config.default_prog = {'nu'}
config.max_fps = 240
config.animation_fps = 1
config.term = "xterm-256color" -- Set the terminal type

config.color_scheme = 'rebecca'
config.font = wezterm.font_with_fallback {'IosevkaTerm Nerd Font', 'Noto Sans CJK HK'}
config.default_cursor_style = "SteadyBlock"
config.window_decorations = "RESIZE"
config.font_size = 14.0
config.window_padding = {
    left = 4,
    right = 4,
    top = 4,
    bottom = 4
}

config.window_frame = {
    font = wezterm.font({
        family = "IosevkaTerm Nerd Font",
        weight = "Bold"
    }),
    active_titlebar_bg = '#232136',
    inactive_titlebar_bg = '#232136'
}

config.initial_cols = 80
config.enable_wayland = false
config.front_end = "WebGpu"

require("modules.tab_bar").setup(config)
return config
