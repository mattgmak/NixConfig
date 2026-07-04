local is_vscode = vim.g.vscode ~= nil

return {
  'stevearc/quicker.nvim',
  cond = not is_vscode,
  event = 'VeryLazy',
  config = function()
    vim.keymap.set('n', '<leader>lq', function() require('quicker').toggle() end, {
      desc = 'Toggle quickfix',
    })
    vim.keymap.set('n', '<leader>ll', function() require('quicker').toggle({ loclist = true }) end, {
      desc = 'Toggle loclist',
    })
    require('quicker').setup({
      keys = {
        {
          '>',
          function() require('quicker').expand({ before = 2, after = 2, add_to_existing = true }) end,
          desc = 'Expand quickfix context',
        },
        {
          '<',
          function() require('quicker').collapse() end,
          desc = 'Collapse quickfix context',
        },
      },
    })
  end,
}
