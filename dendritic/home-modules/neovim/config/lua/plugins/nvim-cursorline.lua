local is_vscode = vim.g.vscode ~= nil

return {
  'ya2s/nvim-cursorline',
  cond = not is_vscode,
  config = function()
    require('nvim-cursorline').setup({
      disable_filetypes = {},
      disable_buftypes = {},
      cursorline = {
        enable = true,
        timeout = 500,
        number = false,
      },
      cursorword = {
        enable = true,
        min_length = 3,
        hl = { underline = true },
      },
    })
  end,
}
