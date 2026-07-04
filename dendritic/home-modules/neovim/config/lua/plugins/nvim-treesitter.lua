local is_vscode = vim.g.vscode ~= nil

return {
  'nvim-treesitter/nvim-treesitter',
  lazy = false,
  build = ':TSUpdate',
  dependencies = { 'nvim-treesitter/nvim-treesitter-textobjects' },
  config = function()
    local ts = require('nvim-treesitter')
    ts.setup({
      install_dir = vim.fn.stdpath('data') .. '/site',
    })
    ts.install({
      'jsx',
      'tsx',
      'javascript',
      'typescript',
      'html',
      'css',
      'json',
      'yaml',
      'toml',
      'markdown',
      'markdown_inline',
      'zig',
      'nix',
      'gitcommit',
    }):wait(300000)
    if not is_vscode then
      vim.api.nvim_create_autocmd('FileType', {
        pattern = { '<filetype>' },
        callback = function() vim.treesitter.start() end,
      })
    end
    vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
  end,
}
