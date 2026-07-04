local is_vscode = vim.g.vscode ~= nil

-- Set enabled = true to activate
return {
  enabled = false,
  'safzanpirani/cursor.nvim',
  cond = not is_vscode,
  lazy = false,
  build = 'cd server; npm install',
  config = function() require('cursor').setup({}) end,
}
