-- Pull in the wezterm API
local wezterm = require("wezterm")
local act = wezterm.action
local config = wezterm.config_builder()

local copy_mode = nil
if wezterm.gui then
    copy_mode = wezterm.gui.default_key_tables().copy_mode
    table.insert(copy_mode, {
        key = 'j',
        mods = 'NONE',
        action = act.CopyMode 'MoveUp'
    })
    table.insert(copy_mode, {
        key = 'k',
        mods = 'NONE',
        action = act.CopyMode 'MoveDown'
    })
    table.insert(copy_mode, {
        key = 'l',
        mods = 'NONE',
        action = act.CopyMode 'MoveLeft'
    })
    table.insert(copy_mode, {
        key = ';',
        mods = 'NONE',
        action = act.CopyMode 'MoveRight'
    })
end

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

for i = 0, 9 do
    -- leader + number to activate that tab
    table.insert(config.keys, {
        key = tostring(i),
        mods = "LEADER",
        action = wezterm.action.ActivateTab(i)
    })
end

-- tab bar
config.hide_tab_bar_if_only_one_tab = false
config.tab_bar_at_bottom = true
config.use_fancy_tab_bar = false
config.tab_and_split_indices_are_zero_based = true

-- tmux status
wezterm.on("update-right-status", function(window, _)
    local SOLID_LEFT_ARROW = ""
    local ARROW_FOREGROUND = {
        Foreground = {
            Color = "#7e5ce5"
        }
    }
    local prefix = ""

    if window:leader_is_active() then
        prefix = " " .. utf8.char(0x1f30a) -- ocean wave
        SOLID_LEFT_ARROW = utf8.char(0xe0b2)
    end

    if window:active_tab():tab_id() ~= 0 then
        ARROW_FOREGROUND = {
            Foreground = {
                Color = "#232136"
            }
        }
    end -- arrow color based on if tab is first pane

    window:set_left_status(wezterm.format {{
        Background = {
            Color = "#b7bdf8"
        }
    }, {
        Text = prefix
    }, ARROW_FOREGROUND, {
        Text = SOLID_LEFT_ARROW
    }})
end)

config.key_tables = {
    copy_mode = copy_mode
}

config.front_end = "OpenGL"
config.default_prog = {'nu'}
config.max_fps = 240
config.animation_fps = 1
config.term = "xterm-256color" -- Set the terminal type

-- config.color_scheme = 'Dracula'
-- config.color_scheme = 'Dark Violet (base16)'
config.color_scheme = 'duskfox'
-- config.font = wezterm.font 'GeistMono Nerd Font Mono'
-- config.font = wezterm.font_with_fallback {'Iosevka Nerd Font Mono', 'Symbols Nerd Font'}
-- config.font = wezterm.font 'IosevkaTerm Nerd Font Mono'
config.font = wezterm.font 'IosevkaTerm Nerd Font'
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
    -- font_size = 14.0
    active_titlebar_bg = '#232136',
    inactive_titlebar_bg = '#232136'
}
config.colors = {
    tab_bar = {
        background = '#232136',
        active_tab = {
            bg_color = '#7e5ce5',
            fg_color = '#FFFFFF'
        },
        inactive_tab = {
            bg_color = '#232136',
            fg_color = '#FFFFFF'
        },
        new_tab = {
            bg_color = '#232136',
            fg_color = '#FFFFFF'
        }
    }
}

-- config.window_decorations = "INTEGRATED_BUTTONS | RESIZE"
config.initial_cols = 80
config.enable_wayland = false
config.front_end = "WebGpu"

return config
