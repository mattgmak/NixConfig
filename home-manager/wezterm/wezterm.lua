-- Pull in the wezterm API
local wez = require("wezterm")
local act = wez.action
local config = wez.config_builder()

local copy_mode = nil
if wez.gui then
    copy_mode = wez.gui.default_key_tables().copy_mode
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
    action = wez.action.SpawnTab "CurrentPaneDomain"
}, {
    mods = "LEADER",
    key = "x",
    action = wez.action.CloseCurrentPane {
        confirm = true
    }
}, {
    mods = "LEADER",
    key = "b",
    action = wez.action.ActivateTabRelative(-1)
}, {
    mods = "LEADER",
    key = "n",
    action = wez.action.ActivateTabRelative(1)
}, {
    mods = "LEADER",
    key = "|",
    action = wez.action.SplitHorizontal {
        domain = "CurrentPaneDomain"
    }
}, {
    mods = "LEADER",
    key = "-",
    action = wez.action.SplitVertical {
        domain = "CurrentPaneDomain"
    }
}, {
    mods = "LEADER",
    key = "l",
    action = wez.action.ActivatePaneDirection "Left"
}, {
    mods = "LEADER",
    key = "k",
    action = wez.action.ActivatePaneDirection "Down"
}, {
    mods = "LEADER",
    key = "j",
    action = wez.action.ActivatePaneDirection "Up"
}, {
    mods = "LEADER",
    key = ";",
    action = wez.action.ActivatePaneDirection "Right"
}, {
    mods = "LEADER",
    key = "LeftArrow",
    action = wez.action.AdjustPaneSize {"Left", 5}
}, {
    mods = "LEADER",
    key = "RightArrow",
    action = wez.action.AdjustPaneSize {"Right", 5}
}, {
    mods = "LEADER",
    key = "DownArrow",
    action = wez.action.AdjustPaneSize {"Down", 5}
}, {
    mods = "LEADER",
    key = "UpArrow",
    action = wez.action.AdjustPaneSize {"Up", 5}
}}

for i = 0, 9 do
    -- leader + number to activate that tab
    table.insert(config.keys, {
        key = tostring(i),
        mods = "LEADER",
        action = wez.action.ActivateTab(i)
    })
end

-- tab bar
config.hide_tab_bar_if_only_one_tab = false
config.tab_bar_at_bottom = true
config.use_fancy_tab_bar = false
config.tab_and_split_indices_are_zero_based = true

-- tmux status
wez.on("update-right-status", function(window, _)
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

    window:set_left_status(wez.format {{
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
config.font = wez.font_with_fallback {'IosevkaTerm Nerd Font', 'Noto Sans CJK HK'}
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
    font = wez.font({
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

-- bar plugin
-- local bar = wez.plugin.require("https://github.com/adriankarlen/bar.wezterm")
-- bar.apply_to_config(config, {
--     position = "bottom",
--     max_width = 32,
--     padding = {
--         left = 1,
--         right = 1
--     },
--     separator = {
--         space = 1,
--         left_icon = wez.nerdfonts.fa_long_arrow_right,
--         right_icon = wez.nerdfonts.fa_long_arrow_left,
--         field_icon = wez.nerdfonts.indent_line
--     },
--     modules = {
--         tabs = {
--             active_tab_fg = 4,
--             inactive_tab_fg = 6
--         },
--         workspace = {
--             enabled = true,
--             icon = wez.nerdfonts.cod_window,
--             color = 8
--         },
--         leader = {
--             enabled = true,
--             icon = wez.nerdfonts.oct_rocket,
--             color = 2
--         },
--         pane = {
--             enabled = true,
--             icon = wez.nerdfonts.cod_multiple_windows,
--             color = 7
--         },
--         username = {
--             enabled = true,
--             icon = wez.nerdfonts.fa_user,
--             color = 6
--         },
--         hostname = {
--             enabled = true,
--             icon = wez.nerdfonts.cod_server,
--             color = 8
--         },
--         clock = {
--             enabled = true,
--             icon = wez.nerdfonts.md_calendar_clock,
--             color = 5
--         },
--         cwd = {
--             enabled = true,
--             icon = wez.nerdfonts.oct_file_directory,
--             color = 7
--         }
--     }
-- })

return config
