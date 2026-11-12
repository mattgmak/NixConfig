-- require("starship"):setup()
require('folder-rules'):setup()
require('relative-motions'):setup({
  show_numbers = 'relative',
  show_motion = true,
})
-- require("searchjump"):setup{
--     opt_unmatch_fg = "#928374",
--     opt_match_str_fg = "#000000",
--     opt_match_str_bg = "#73AC3A",
--     opt_lable_fg = "#EADFC8",
--     opt_lable_bg = "#BA603D"
-- }
-- require("yaziline"):setup({
--     separator_style = "curvy", -- "angly" | "curvy" | "liney" | "empty"
--     -- separator_open = "",
--     -- separator_close = "",
--     -- separator_open_thin = "",
--     -- separator_close_thin = "",
--     select_symbol = "",
--     yank_symbol = "󰆐",
--     filename_max_length = 24, -- trim when filename > 24
--     filename_trim_length = 6 -- trim 6 chars from both ends
-- })

require('fg'):setup({
  default_action = 'menu',
})
require('fg-rga'):setup({
  default_action = 'menu',
})

th.git = th.git or {}
th.git.modified = ui.Style():fg('yellow')
th.git.deleted = ui.Style():fg('red'):bold()
th.git.modified_sign = 'M'
th.git.deleted_sign = 'D'
th.git.untracked = ui.Style():fg('blue')
th.git.untracked_sign = 'U'
th.git.renamed = ui.Style():fg('magenta')
th.git.renamed_sign = 'R'
th.git.staged = ui.Style():fg('green')
require('git'):setup()


require('yatline'):setup({
  header_line = {
    left = {
      section_a = {
        { type = 'line', name = 'tabs' },
      },
      section_b = {
        { type = 'coloreds', custom = false, name = 'tab_path' },
      },
      section_c = {},
    },
    right = {
      section_a = {
        { type = 'string', name = 'date', params = { '%A, %d %B %Y' } },
      },
      section_b = {
        { type = 'string', name = 'date', params = { '%X' } },
      },
      section_c = {},
    },
  },

  status_line = {
    left = {
      section_a = {
        { type = 'string', name = 'tab_mode' },
      },
      section_b = {
        { type = 'string', name = 'hovered_size' },
        { type = 'coloreds', custom = false, name = 'selected-files-size' },
      },
      section_c = {
        { type = 'string', name = 'hovered_path' },
        { type = 'coloreds', custom = false, name = 'symlink' },
        { type = 'coloreds', name = 'count' },
      },
    },
    right = {
      section_a = {
        { type = 'string', name = 'cursor_position' },
      },
      section_b = {
        { type = 'string', name = 'cursor_percentage' },
        { type = 'coloreds', custom = false, name = 'page_count' },
        { type = 'coloreds', custom = false, name = 'modified_time' },
        { type = 'coloreds', custom = false, name = 'created_time' },
      },
      section_c = {
        { type = 'string', name = 'hovered_file_extension', params = { true } },
        { type = 'coloreds', name = 'permissions' },
        { type = 'string', name = 'hovered_ownership' },
      },
    },
  },
})

-- Yatline addons need the global Yatline, so they load after its setup.
require('yatline-tab-path'):setup()
require('yatline-symlink'):setup({
  symlink_color = 'white',
})
require('yatline-selected-size'):setup()
require('yatline-modified-time'):setup()
require('yatline-created-time'):setup()
require('yatline-page-counter'):setup({
  show_icon = false,
})

-- Renders mermaid blocks in Markdown previews. yazi.toml maps *.md to this plugin.
require('mermaid'):setup({
  backend = 'auto',
  format = 'png',
})
