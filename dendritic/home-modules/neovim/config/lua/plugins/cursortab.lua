local is_vscode = vim.g.vscode ~= nil

-- Set enabled = true to activate
return {
  enabled = false,
  'cursortab/cursortab.nvim',
  cond = not is_vscode,
  lazy = false,
  build = 'go build -C server',
  config = function()
    require('cursortab').setup({
      -- provider = {
      --   type = 'sweep',
      --   url = 'http://127.0.0.1:9292',
      --   model = 'sweep-next-edit:1.5b-q8',
      -- },
      provider = {
        type = 'mercuryapi',
        api_key_env = 'MERCURY_AI_TOKEN',
      },
      blink = {
        enabled = true,
      },
    })
  end,
}
