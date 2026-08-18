local is_vscode = vim.g.vscode ~= nil

--- Only persist when launched via the `v` shell alias (sets NVIM_PERSIST_SESSION=1).
--- Ephemeral editor spawns (lazygit, git commit, pi prompt edit, yazi, etc.) use
--- plain `nvim` and must not overwrite the saved session on exit.
local function should_persist_session()
  if vim.env.NVIM_PERSIST_SESSION ~= '1' then
    return false
  end

  -- pi-nvim-bridge sets this when pi spawns the editor for prompt editing.
  if vim.env.PI_NVIM_BRIDGE and vim.env.PI_NVIM_BRIDGE ~= '' then
    return false
  end

  return true
end

local function wipe_no_neck_pain_buffers()
  for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
      local buf = vim.api.nvim_win_get_buf(win)
      if vim.bo[buf].filetype == 'no-neck-pain' then vim.api.nvim_win_close(win, true) end
    end
  end

  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].filetype == 'no-neck-pain' then
      vim.api.nvim_buf_delete(buf, { force = true })
    end
  end
end

return {
  'folke/persistence.nvim',
  event = { 'VimEnter', 'BufReadPre' },
  cond = not is_vscode,
  opts = {},
  keys = {
    {
      '<leader>qs',
      function() require('persistence').load() end,
      desc = 'Restore session',
    },
    {
      '<leader>qS',
      function() require('persistence').select() end,
      desc = 'Select session',
    },
    {
      '<leader>ql',
      function() require('persistence').load({ last = true }) end,
      desc = 'Restore last session',
    },
    {
      '<leader>qd',
      function() require('persistence').stop() end,
      desc = 'Stop session autosave',
    },
    { '<leader>qq', '<cmd>qa<cr>', desc = 'Quit all' },
    { '<leader>qQ', '<cmd>qa!<cr>', desc = 'Force quit all' },
  },
  config = function(_, opts)
    require('persistence').setup(opts)

    local group = vim.api.nvim_create_augroup('persistence_hooks', { clear = true })

    vim.api.nvim_create_autocmd('User', {
      group = group,
      pattern = 'PersistenceLoadPre',
      callback = function()
        -- Neovim's startup [No Name] buffer shifts buffer numbers; wipe before sourcing.
        vim.cmd('silent! tabonly | silent! %bwipeout!')
      end,
    })

    vim.api.nvim_create_autocmd('User', {
      group = group,
      pattern = 'PersistenceSavePre',
      callback = wipe_no_neck_pain_buffers,
    })

    vim.api.nvim_create_autocmd('User', {
      group = group,
      pattern = 'PersistenceLoadPost',
      callback = wipe_no_neck_pain_buffers,
    })

    if not should_persist_session() then
      require('persistence').stop()
      return
    end

    if vim.fn.argc() == 0 then
      vim.schedule(function()
        require('persistence').load()
      end)
    end
  end,
}
