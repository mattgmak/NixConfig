local M = {}

M._loaded = false

function M.get_selection()
  local mode = vim.fn.mode()
  if mode ~= 'v' and mode ~= 'V' and mode ~= '\22' then
    return nil
  end
  vim.cmd('noau normal! "vy"')
  local selection = vim.fn.getreg('v')
  return vim.trim((selection:gsub('\r\n', '\n'):gsub('\r', '\n'):gsub('\n+', ' '):gsub('%s+', ' ')))
end

function M.setup()
  if M._loaded then
    return
  end
  M._loaded = true

  local actions = require('telescope.actions')
  local actions_layout = require('telescope.actions.layout')
  require('telescope').setup({
    defaults = {
      mappings = {
        i = {
          ['<C-h>'] = actions_layout.toggle_preview,
          ['<C-s>'] = actions.select_horizontal,
          ['<C-x>'] = false,
        },
        n = {
          ['<C-h>'] = actions_layout.toggle_preview,
          ['<C-s>'] = actions.select_horizontal,
          ['<C-x>'] = false,
        },
      },
      cache_picker = {
        num_pickers = 30,
        limit_entries = 1000,
        ignore_empty_prompt = true,
      },
    },
    pickers = {
      buffers = {
        mappings = {
          i = {
            ['<C-x>'] = actions.delete_buffer,
          },
          n = {
            ['<C-x>'] = actions.delete_buffer,
          },
        },
      },
    },
  })
  pcall(require('telescope').load_extension, 'fzf')
end

function M.ensure_loaded()
  M.setup()
end

return M
