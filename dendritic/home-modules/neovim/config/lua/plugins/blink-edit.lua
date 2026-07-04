local is_vscode = vim.g.vscode ~= nil

-- Set enabled = true to activate
return {
  enabled = false,
  'BlinkResearchLabs/blink-edit.nvim',
  cond = not is_vscode,
  config = function()
    require('blink-edit').setup({
      llm = {
        provider = 'sweep',
        backend = 'openai',
        url = 'http://127.0.0.1:9292',
        model = 'sweep-next-edit:1.5b-q8',
      },
      ui = {
        progress = false,
        context = {
          history = {
            enabled = false,
            max_items = 5,
            max_tokens = 512,
            max_files = 2,
            global = true,
          },
        },
      },
    })
  end,
}
