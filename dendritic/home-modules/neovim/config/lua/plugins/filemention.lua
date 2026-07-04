local is_vscode = vim.g.vscode ~= nil

return {
  'not-manu/filemention.nvim',
  cond = not is_vscode,
  event = 'InsertEnter',
  dependencies = {
    {
      'dmtrKovalenko/fff.nvim',
      build = function() require('fff.download').download_or_build_binary() end,
    },
  },
  opts = { finder = 'fff' },
}
