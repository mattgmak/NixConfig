local is_vscode = vim.g.vscode ~= nil

if not is_vscode then require('vim._core.ui2').enable({}) end

-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath('data') .. '/lazy/lazy.nvim'
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = 'https://github.com/folke/lazy.nvim.git'
  local out = vim.fn.system({ 'git', 'clone', '--filter=blob:none', '--branch=stable', lazyrepo, lazypath })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo(
      { { 'Failed to clone lazy.nvim:\n', 'ErrorMsg' }, { out, 'WarningMsg' }, { '\nPress any key to exit...' } },
      true,
      {}
    )
    vim.fn.getchar()
    os.exit(1)
  end
end
vim.opt.rtp:prepend(lazypath)

-- Setup lazy.nvim
require('lazy').setup({
  {
    'vscode-neovim/vscode-multi-cursor.nvim',
    event = 'VeryLazy',
    cond = is_vscode,
    opts = {},
  },
  {
    'lewis6991/gitsigns.nvim',
    event = { 'BufReadPost', 'BufNewFile' },
    cond = function()
      return not vim.g.vscode
    end,
    opts = {
      on_attach = function(bufnr)
        local gs = require('gitsigns')

        local function map(mode, lhs, rhs, desc)
          vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc })
        end

        map('n', '<leader>fc', function()
          gs.setqflist('all', { open = true })
        end, 'Gitsigns: QF all hunks (SCM)')
        map('n', '<leader>fl', function()
          gs.setqflist('attached', { open = true })
        end, 'Gitsigns: QF attached hunks (GitLens-ish)')
        map('n', '<leader>wc', function()
          gs.preview_hunk_inline()
        end, 'Gitsigns: next hunk (dirty diff)')
        map('n', '<leader>n', function()
          gs.nav_hunk('next')
        end, 'Gitsigns: next hunk')
        map('n', '<leader>b', function()
          gs.nav_hunk('prev')
        end, 'Gitsigns: prev hunk')
        map('v', 'R', function()
          local s, e = vim.fn.line('v'), vim.fn.line('.')
          if s > e then s, e = e, s end
          gs.reset_hunk({ s, e })
        end, 'Gitsigns: reset hunk (visual range)')
      end,
    },
  },
  --   {
  --     'folke/flash.nvim',
  --     event = 'VeryLazy',
  --     ---@type Flash.Config
  --     opts = {},
  --     -- stylua: ignore
  --     keys = {{
  --         "<BS>",
  --         mode = {"n", "x", "o"},
  --         function()
  --             require("flash").jump()
  --         end,
  --         desc = "Flash"
  --     }, {
  --         "S",
  --         mode = {"n", "x", "o"},
  --         function()
  --             require("flash").treesitter()
  --         end,
  --         desc = "Flash Treesitter"
  --     }, {
  --         "r",
  --         mode = "o",
  --         function()
  --             require("flash").remote()
  --         end,
  --         desc = "Remote Flash"
  --     }, {
  --         "R",
  --         mode = {"o", "x"},
  --         function()
  --             require("flash").treesitter_search()
  --         end,
  --         desc = "Treesitter Search"
  --     }}
  -- ,
  --   },
  {
    url = 'https://codeberg.org/andyg/leap.nvim',
    config = function(_, opts)
      -- vim.keymap.set({ 'n', 'x', 'o' }, '<BS>', '<Plug>(leap)')
      -- vim.keymap.set({ 'n', 'x', 'o' }, 'gh', '<Plug>(leap)')
      vim.keymap.set({ 'n', 'x', 'o' }, '<BS>', '<Plug>(leap)')
      vim.keymap.set({ 'n', 'x', 'o' }, 'gh', '<Plug>(leap)')
      vim.keymap.set({ 'n' }, '<leader><BS>', '<Plug>(leap-anywhere)')
      vim.keymap.set({ 'n' }, '<leader>gh', '<Plug>(leap-anywhere)')
      vim.keymap.set({ 'n', 'o' }, 'gs', function()
        require('leap.remote').action({
          -- Automatically enter Visual mode when coming from Normal.
          input = vim.fn.mode(true):match('o') and '' or 'v',
        })
      end)

      require('leap').opts.preview = function(ch0, ch1, ch2)
        return not (ch1:match('%s') or (ch0:match('%a') and ch1:match('%a') and ch2:match('%a')))
      end

      -- `on_beacons` hooks into `beacons.light_up_beacons`, the function
      -- responsible for displaying stuff.
      require('leap').opts.on_beacons = function(targets, _, _)
        for _, t in ipairs(targets) do
          -- Overwrite the `offset` value in all beacons.
          -- target.beacon looks like: { <offset>, <extmark_opts> }
          if t.label and t.beacon then t.beacon[1] = 0 end
        end
      end

      vim.api.nvim_set_hl(0, 'LeapBackdrop', { link = 'Comment' })
    end,
  },
  {
    'nvim-treesitter/nvim-treesitter',
    lazy = false,
    build = ':TSUpdate',
    dependencies = { 'nvim-treesitter/nvim-treesitter-textobjects' },
    config = function()
      local ts = require('nvim-treesitter')
      ts.setup({
        install_dir = vim.fn.stdpath('data') .. '/site',
      })
      ts.install({
        'jsx',
        'tsx',
        'javascript',
        'typescript',
        'html',
        'css',
        'json',
        'yaml',
        'toml',
        'markdown',
        'markdown_inline',
        'zig',
        'nix',
      }):wait(300000)
      if not is_vscode then
        vim.api.nvim_create_autocmd('FileType', {
          pattern = { '<filetype>' },
          callback = function() vim.treesitter.start() end,
        })
      end
      vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
    end,
  },
  {
    'nvim-treesitter/nvim-treesitter-textobjects',
    branch = 'main',
  },
  {
    'nvim-mini/mini.nvim',
    version = '*',
    event = 'VeryLazy',
    config = function()
      local gen_ai_spec = require('mini.extra').gen_ai_spec
      local spec_treesitter = require('mini.ai').gen_spec.treesitter
      require('mini.ai').setup({
        custom_textobjects = {
          B = gen_ai_spec.buffer(),
          D = gen_ai_spec.diagnostic(),
          I = gen_ai_spec.indent(),
          L = gen_ai_spec.line(),
          N = gen_ai_spec.number(),
          -- Classname textobject (for Tailwind CSS classes)
          -- Matches space-separated words within quotes
          -- 'a' includes surrounding space, 'i' is just the word
          c = {
            { '%b""', "%b''", '%b``' },
            -- 'a' includes trailing space(s), 'i' is just the word
            {
              '[\'"`]()()[^%s\'"`]+()()[\'"`]', -- Single classname
              '[\'"`]()()[^%s\'"`]+()%s+()',    -- First of multiple classnames
              '()%s+()[^%s\'"`]+()()[\'"`]',    -- Last of multiple classnames
              '%s+()()[^%s\'"`]+()%s+()',       -- Middle of multiple classnames
            },
          },
          -- Tag attribute textobject (for HTML/XML tags)
          -- Requires nvim-treesitter-textobjects plugin
          T = spec_treesitter({ a = '@attribute.outer', i = '@attribute.inner' }),
        },
      })
      require('mini.surround').setup()
      if not is_vscode then require('mini.statusline').setup() end
    end,
  },
  { 'actionshrimp/direnv.nvim', opts = {} },
  {
    'stevearc/oil.nvim',
    cond = not is_vscode,
    event = 'VeryLazy',
    config = function()
      require('oil').setup({})
      vim.keymap.set('n', '<leader>ff', '<cmd>Oil<cr>', { desc = 'Oil file browser' })
    end,
  },
  {
    'nvim-telescope/telescope.nvim',
    version = '*',
    cond = not is_vscode,
    event = 'VeryLazy',
    dependencies = {
      'nvim-lua/plenary.nvim',
      { 'nvim-telescope/telescope-fzf-native.nvim', build = 'make' },
    },
    config = function()
      require('telescope').setup({})
      pcall(require('telescope').load_extension, 'fzf')

      local builtin = require('telescope.builtin')
      function get_selection()
        vim.cmd('noau normal! "vy"')
        local selection = vim.fn.getreg('v')
        local query = vim.trim((selection:gsub('\r\n', '\n'):gsub('\r', '\n'):gsub('\n+', ' '):gsub('%s+', ' ')))
        return query
      end

      vim.keymap.set({ 'n' }, '<leader><leader>', function() builtin.find_files() end, { desc = 'Find files' })
      vim.keymap.set({ 'v' }, '<leader><leader>', function()
        builtin.find_files({
          default_text = get_selection()
        })
      end, { desc = 'Find files' })
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
      vim.keymap.set({ 'v' }, '<leader>jf', function()
        builtin.current_buffer_fuzzy_find({
          default_text = get_selection()
        })
      end, {
        desc = 'Find in active file',
      })
      vim.keymap.set({ 'n' }, '<leader>jg', function()
        builtin.live_grep()
      end, { desc = 'Find within files' })
      vim.keymap.set({ 'v' }, '<leader>jg', function()
        local query = vim.fn.escape(get_selection(), [[\/.*$^~[()]])
        builtin.live_grep({
          default_text = query,
        })
      end, { desc = 'Find within files' })
      vim.keymap.set('n', '<leader>jv', function() builtin.resume() end, { desc = 'Resume last Telescope' })
      vim.keymap.set('n', '<leader>ja', function() builtin.lsp_workspace_symbols() end, { desc = 'Workspace symbols' })
      vim.keymap.set('n', '<leader>k', function() builtin.buffers({ sort_mru = true }) end, { desc = 'Buffers MRU' })
      vim.keymap.set('n', '<leader>,', function() builtin.buffers() end, { desc = 'All editors / buffers' })
      vim.keymap.set('n', '<leader>jh', function() builtin.help_tags() end, { desc = 'Help tags' })
    end,
  },
  {
    'MagicDuck/grug-far.nvim',
    cond = not is_vscode,
    -- Note (lazy loading): grug-far.lua defers all it's requires so it's lazy by default
    -- additional lazy config to defer loading is not really needed...
    config = function()
      -- optional setup call to override plugin options
      -- alternatively you can set options with vim.g.grug_far = { ... }
      require('grug-far').setup({
        -- options, see Configuration section below
        -- there are no required options atm
      })
    end,
  },
  {
    'BlinkResearchLabs/blink-edit.nvim',
    enabled = not is_vscode,
    config = function()
      require('blink-edit').setup({
        llm = {
          provider = 'sweep',
          backend = 'openai',
          url = 'http://localhost:8000',
          model = 'sweep',
        },
      })
    end,
  },
  {
    'neovim/nvim-lspconfig',
    config = function()
      vim.lsp.enable('lua_ls')
      vim.lsp.enable('nixd')
    end,
  },
  {
    'folke/lazydev.nvim',
    ft = 'lua', -- only load on lua files
    opts = {
      library = {
        -- See the configuration section for more details
        -- Load luvit types when the `vim.uv` word is found
        { path = '${3rd}/luv/library', words = { 'vim%.uv' } },
      },
    },
  },
  {
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
  },
  {
    'saghen/blink.cmp',
    -- dependencies = { 'rafamadriz/friendly-snippets' },
    cond = not is_vscode,
    version = '1.*',
    ---@module 'blink.cmp'
    ---@type blink.cmp.Config
    opts = {
      -- 'default' (recommended) for mappings similar to built-in completions (C-y to accept)
      -- 'super-tab' for mappings similar to vscode (tab to accept)
      -- 'enter' for enter to accept
      -- 'none' for no mappings
      --
      -- All presets have the following mappings:
      -- C-space: Open menu or open docs if already open
      -- C-n/C-p or Up/Down: Select next/previous item
      -- C-e: Hide menu
      -- C-k: Toggle signature help (if signature.enabled = true)
      --
      -- See :h blink-cmp-config-keymap for defining your own keymap
      keymap = { preset = 'default' },

      appearance = {
        nerd_font_variant = 'mono',
      },

      -- (Default) Only show the documentation popup when manually triggered
      completion = { documentation = { auto_show = false } },

      -- Default list of enabled providers defined so that you can extend it
      -- elsewhere in your config, without redefining it, due to `opts_extend`
      sources = {
        default = { 'lsp', 'path', 'snippets', 'buffer' },
      },

      fuzzy = { implementation = 'prefer_rust_with_warning' },
    },
    opts_extend = { 'sources.default' },
  },
})
