return {
  'nvim-treesitter/nvim-treesitter-context',
  config = function()
    require('treesitter-context').setup({
      max_lines = 10,
    })
    vim.keymap.set(
      { 'n', 'v' },
      '[c',
      function() require('treesitter-context').go_to_context(vim.v.count1) end,
      { silent = true }
    )
  end,
}
