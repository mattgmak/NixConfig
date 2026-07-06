local is_vscode = vim.g.vscode ~= nil

return {
  'tjgao/quickbuf.nvim',
  cond = not is_vscode,
  event = 'VeryLazy',
  priority = 1000,
  keys = {
    { '<leader>k', '<cmd>QuickBuf<CR>', desc = 'QuickBuf' },
    { '<leader>p', '<cmd>QuickBufPinToggle<CR>', desc = 'Pin toggle' },
    { '<S-h>', '<cmd>QuickBufPrevPinned<CR>', desc = 'Prev pinned buffer' },
    { '<S-l>', '<cmd>QuickBufNextPinned<CR>', desc = 'Next pinned buffer' },
  },
  config = function()
    require('quickbuf').setup({
      include_special = false,
      auto_jump_single = false,
      isolate_keymaps = true,
      fuzzy_key = '/',
      fuzzy_backend = 'telescope',
      fuzzy_open = nil,
      -- alternate_key = '<Tab>',
      -- alternate_key_display = '',
      alternate_key = ' ',
      alternate_key_display = '󱁐',
      alternate_without_label = true,
      picker = {
        move_up_key = 'k',
        move_down_key = 'j',
        select_key = '<CR>',
        toggle_pin_key = 'T',
      },
      show_icons = true,
      highlights = {
        label = { link = 'DiagnosticWarn', bold = true },
        pinned = { link = 'DiagnosticOk' },
        flags = { link = 'Comment' },
        alternate = { fg = '#ff8800', bold = true },
        filename = { link = 'Normal' },
        path = { link = 'Comment' },
        muted = { link = 'Comment' },
        cursorline = { link = 'Visual' },
      },
      window = {
        border = 'rounded',
        width = nil,
        height = nil,
        max_width = 80,
        min_width = 36,
        padding = 2,
        vertical_padding = 1,
      },
    })
  end,
}
