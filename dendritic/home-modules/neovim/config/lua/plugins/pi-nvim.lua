local is_vscode = vim.g.vscode ~= nil

return {
  'carderne/pi-nvim',
  -- Pin to the vendored submodule (see pi-bridge.lua for the same rationale):
  -- the pi extension half loads from vendor/carderne/pi-nvim, so the nvim
  -- plugin must match that exact revision.
  dir = vim.fn.expand('$HOME') .. '/NixConfig/vendor/carderne/pi-nvim',
  cond = not is_vscode,
  config = function()
    require('pi-nvim').setup()
    vim.keymap.set('n', '<leader>pp', ':PiSend<CR>', { desc = 'Send prompt to pi' })
    vim.keymap.set('n', '<leader>pf', ':PiSendFile<CR>', { desc = 'Send file to pi' })
    vim.keymap.set('v', '<leader>ps', ':Pi<CR>', { desc = 'Send selection to pi' })
    vim.keymap.set('n', '<leader>pb', ':PiSendBuffer<CR>', { desc = 'Send buffer to pi' })
    vim.keymap.set('n', '<leader>pi', ':PiPing<CR>', { desc = 'Ping pi session' })
  end,
}
