local is_vscode = vim.g.vscode ~= nil

return {
  'MagicDuck/grug-far.nvim',
  cond = not is_vscode,
  config = function() require('grug-far').setup({}) end,
}
