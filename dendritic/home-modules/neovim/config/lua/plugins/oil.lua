local is_vscode = vim.g.vscode ~= nil

return {
  'stevearc/oil.nvim',
  cond = not is_vscode,
  event = 'VeryLazy',
  config = function()
    require('oil').setup({})
    vim.keymap.set('n', '<leader>ff', '<cmd>Oil<cr>', { desc = 'Oil file browser' })
  end,
}
