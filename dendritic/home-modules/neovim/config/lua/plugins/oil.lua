local is_vscode = vim.g.vscode ~= nil

return {
  'stevearc/oil.nvim',
  cond = not is_vscode,
  lazy = false,
  dependencies = { 'nvim-tree/nvim-web-devicons' },
  config = function()
    require('oil').setup({
      default_file_explorer = true,
    })
    vim.keymap.set('n', '<leader>ff', '<cmd>Oil<cr>', { desc = 'Oil file browser' })
  end,
}
