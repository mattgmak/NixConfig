local is_vscode = vim.g.vscode ~= nil

return {
  name = 'multigrep',
  dir = vim.fn.stdpath('config') .. '/lua/multigrep',
  dependencies = { 'nvim-telescope/telescope.nvim' },
  cond = not is_vscode,
  event = 'VeryLazy',
  config = function()
    local multigrep = require('multigrep')

    local function get_selection()
      vim.cmd('noau normal! "vy"')
      local selection = vim.fn.getreg('v')
      return vim.trim((selection:gsub('\r\n', '\n'):gsub('\r', '\n'):gsub('\n+', ' '):gsub('%s+', ' ')))
    end

    vim.keymap.set('n', '<leader>jg', function() multigrep.live() end, { desc = 'Find within files' })
    vim.keymap.set('v', '<leader>jg', function()
      multigrep.live({
        default_text = vim.fn.escape(get_selection(), [=[\/.*$^~[()]]=]),
      })
    end, { desc = 'Find within files' })
  end,
}
