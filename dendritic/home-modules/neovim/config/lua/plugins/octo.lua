local is_vscode = vim.g.vscode ~= nil

return {
  'pwntester/octo.nvim',
  cmd = 'Octo',
  cond = not is_vscode,
  dependencies = {
    'nvim-lua/plenary.nvim',
    'nvim-telescope/telescope.nvim',
    'nvim-tree/nvim-web-devicons',
  },
  opts = {
    picker = 'telescope',
  },
  config = function()
    require('octo').setup({
      picker = 'telescope',
      enable_builtin = true,
      use_local_fs = true,
    })
    pcall(require('telescope').load_extension, 'octo')
    vim.keymap.set('n', '<leader>o', '<cmd>Octo<cr>', { desc = 'Octo picker' })
  end,
}
