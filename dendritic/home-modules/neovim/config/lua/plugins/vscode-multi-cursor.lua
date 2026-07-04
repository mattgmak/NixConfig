local is_vscode = vim.g.vscode ~= nil

return {
  'vscode-neovim/vscode-multi-cursor.nvim',
  event = 'VeryLazy',
  cond = is_vscode,
  opts = {},
}
