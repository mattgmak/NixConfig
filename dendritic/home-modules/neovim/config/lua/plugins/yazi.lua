local is_vscode = vim.g.vscode ~= nil

return {
  'mikavilpas/yazi.nvim',
  version = '*',
  cond = not is_vscode,
  event = 'VeryLazy',
  dependencies = {
    { 'nvim-lua/plenary.nvim', lazy = true },
  },
  opts = {},
  config = function(_, opts)
    require('yazi').setup(opts)
    vim.keymap.set('n', '<leader>fy', '<cmd>Yazi<cr>', { desc = 'Yazi at current file' })
    vim.keymap.set('n', '<leader>fd', '<cmd>Yazi cwd<cr>', { desc = 'Yazi cwd' })
  end,
}
