local is_vscode = vim.g.vscode ~= nil

return {
  'carderne/pi-nvim',
  cond = not is_vscode,
  config = function()
    require('pi-nvim').setup()
    vim.keymap.set('n', '<leader>pp', ':PiSend<CR>', { desc = 'Send prompt to pi' })
    vim.keymap.set('n', '<leader>pf', ':PiSendFile<CR>', { desc = 'Send file to pi' })
    vim.keymap.set('v', '<leader>ps', ':PiSendSelection<CR>', { desc = 'Send selection to pi' })
    vim.keymap.set('n', '<leader>pb', ':PiSendBuffer<CR>', { desc = 'Send buffer to pi' })
    vim.keymap.set('n', '<leader>pi', ':PiPing<CR>', { desc = 'Ping pi session' })
  end,
}
