local is_vscode = vim.g.vscode ~= nil

return {
  'barrettruth/diffs.nvim',
  cond = not is_vscode,
  init = function()
    vim.g.diffs = {
      integrations = {
        gitsigns = true,
      },
    }
  end,
}
