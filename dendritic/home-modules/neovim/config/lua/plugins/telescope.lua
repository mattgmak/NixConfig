local is_vscode = vim.g.vscode ~= nil

return {
  'nvim-telescope/telescope.nvim',
  version = '*',
  cond = not is_vscode,
  event = 'VeryLazy',
  dependencies = {
    'nvim-lua/plenary.nvim',
    'nvim-tree/nvim-web-devicons',
    { 'nvim-telescope/telescope-fzf-native.nvim', build = 'make' },
  },
  config = function()
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

    local builtin = require('telescope.builtin')
    local function get_selection()
      vim.cmd('noau normal! "vy"')
      local selection = vim.fn.getreg('v')
      local query = vim.trim((selection:gsub('\r\n', '\n'):gsub('\r', '\n'):gsub('\n+', ' '):gsub('%s+', ' ')))
      return query
    end

    vim.keymap.set({ 'n' }, '<leader>jj', function() builtin.builtin() end, { desc = 'Telescope builtins' })
    vim.keymap.set({ 'n' }, '<leader><leader>', function() builtin.find_files() end, { desc = 'Find files' })
    vim.keymap.set(
      { 'v' },
      '<leader><leader>',
      function()
        builtin.find_files({
          default_text = get_selection(),
        })
      end,
      { desc = 'Find files' }
    )
    vim.keymap.set({ 'n' }, '<leader><S-Space>', function()
      builtin.find_files({ hidden = true })
    end, { desc = 'Find files (hidden)' })
    vim.keymap.set(
      { 'v' },
      '<leader><S-Space>',
      function()
        builtin.find_files({
          hidden = true,
          default_text = get_selection(),
        })
      end,
      { desc = 'Find files (hidden)' }
    )
    vim.keymap.set('n', '<leader>js', function() builtin.lsp_document_symbols() end, { desc = 'Goto symbol in file' })
    vim.keymap.set(
      'n',
      '<leader>jc',
      function()
        builtin.lsp_document_symbols({
          symbols = { 'method', 'function', 'constructor', 'field', 'class', 'struct', 'interface' },
        })
      end,
      { desc = 'Symbol outline (breadcrumb-ish)' }
    )
    vim.keymap.set({ 'n' }, '<leader>jf', function() builtin.current_buffer_fuzzy_find() end, {
      desc = 'Find in active file',
    })
    vim.keymap.set(
      { 'v' },
      '<leader>jf',
      function()
        builtin.current_buffer_fuzzy_find({
          default_text = get_selection(),
        })
      end,
      {
        desc = 'Find in active file',
      }
    )
    vim.keymap.set({ 'n' }, '<leader>jp', function() builtin.pickers() end, {
      desc = 'Find cached pickers',
    })

    vim.keymap.set('n', '<leader>jv', function() builtin.resume() end, { desc = 'Resume last Telescope' })
    vim.keymap.set('n', '<leader>ja', function() builtin.lsp_workspace_symbols() end, { desc = 'Workspace symbols' })
    -- vim.keymap.set(
    --   'n',
    --   '<leader>k',
    --   function()
    --     builtin.buffers({
    --       sort_mru = true,
    --       ignore_current_buffer = true,
    --     })
    --   end,
    --   { desc = 'Buffers MRU' }
    -- )
    vim.keymap.set('n', '<leader>jh', function() builtin.help_tags() end, { desc = 'Help tags' })
    vim.keymap.set(
      { 'v' },
      '<leader>jh',
      function()
        builtin.help_tags({
          default_text = get_selection(),
        })
      end,
      { desc = 'Help tags' }
    )
    vim.keymap.set('n', '<leader>jd', function() builtin.lsp_definitions() end, { desc = 'LSP definitions' })
    vim.keymap.set(
      { 'v' },
      '<leader>jd',
      function()
        builtin.lsp_definitions({
          default_text = get_selection(),
        })
      end,
      { desc = 'LSP definitions' }
    )
    vim.keymap.set('n', '<leader>jr', function() builtin.lsp_references() end, { desc = 'LSP references' })
    vim.keymap.set(
      { 'v' },
      '<leader>jr',
      function()
        builtin.lsp_references({
          default_text = get_selection(),
        })
      end,
      { desc = 'LSP references' }
    )
  end,
}
