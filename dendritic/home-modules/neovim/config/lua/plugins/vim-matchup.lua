return {
  'andymass/vim-matchup',
  config = function()
    require('match-up').setup({
      text_obj = {
        enabled = 1,
        linewise_operators = {},
      },
      treesitter = {
        enabled = true,
        disabled = {},
        disable_virtual_text = false,
        enable_quotes = true,
        stopline = 500,
        include_match_words = true,
      },
      matchparen = {
        deferred = 1,
        enabled = 1,
        hi_surround_always = 1,
        offscreen = { method = 'popup' },
        stopline = 400,
      },
      surround = { enabled = 0 },
    })
  end,
}
