local wezterm = require("wezterm")
local tabline = wezterm.plugin.require("https://github.com/michaelbrusegard/tabline.wez")

local function setup_tab_bar(config)
    -- tab bar
    config.hide_tab_bar_if_only_one_tab = false
    config.tab_bar_at_bottom = true
    config.use_fancy_tab_bar = false
    config.tab_and_split_indices_are_zero_based = true

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

    -- Set up tabline plugin
    tabline.setup({
        options = {
            icons_enabled = true,
            theme = 'Catppuccin Mocha',
            tabs_enabled = true,
            theme_overrides = {},
            section_separators = {
                left = wezterm.nerdfonts.pl_left_hard_divider,
                right = wezterm.nerdfonts.pl_right_hard_divider
            },
            component_separators = {
                left = wezterm.nerdfonts.pl_left_soft_divider,
                right = wezterm.nerdfonts.pl_right_soft_divider
            },
            tab_separators = {
                left = wezterm.nerdfonts.pl_left_hard_divider,
                right = wezterm.nerdfonts.pl_right_hard_divider
            }
        },
        sections = {
            tabline_a = {'mode'},
            tabline_b = {'workspace'},
            tabline_c = {' '},
            tab_active = {'index', {
                'parent',
                padding = 0
            }, '/', {
                'cwd',
                padding = {
                    left = 0,
                    right = 1
                }
            }, {
                'zoomed',
                padding = 0
            }},
            tab_inactive = {'index', {
                'process',
                padding = {
                    left = 0,
                    right = 1
                }
            }},
            tabline_x = {'ram', 'cpu'},
            tabline_y = {'datetime', 'battery'},
            tabline_z = {'domain'}
        },
        extensions = {}
    })
    tabline.apply_to_config(config)

    return config
end

return setup_tab_bar
