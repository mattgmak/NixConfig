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
    cond = function() return not vim.g.vscode end,
    opts = {
      on_attach = function(bufnr)
        local gs = require('gitsigns')
        gs.setup({})

        local function map(mode, lhs, rhs, desc) vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc }) end

        map('n', '<leader>fc', function() gs.setqflist('all', { open = true }) end, 'Gitsigns: QF all hunks (SCM)')
        map(
          'n',
          '<leader>fl',
          function() gs.setqflist('attached', { open = true }) end,
          'Gitsigns: QF attached hunks (GitLens-ish)'
        )
        map('n', '<leader>wc', function() gs.preview_hunk_inline() end, 'Gitsigns: next hunk (dirty diff)')
        map('n', '<leader>n', function() gs.nav_hunk('next') end, 'Gitsigns: next hunk')
        map('n', '<leader>b', function() gs.nav_hunk('prev') end, 'Gitsigns: prev hunk')
        map('v', 'R', function()
          local s, e = vim.fn.line('v'), vim.fn.line('.')
          if s > e then
            s, e = e, s
          end
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
    'nvim-treesitter/nvim-treesitter-context',
    config = function()
      require('treesitter-context').setup({
        max_lines = 10,
      })
      vim.keymap.set(
        { 'n', 'v' },
        '[c',
        function() require('treesitter-context').go_to_context(vim.v.count1) end,
        { silent = true }
      )
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
        'gitcommit',
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
    'andymass/vim-matchup',
    -- cond = not is_vscode,
    -- matchup loads minimal startup code; avoid deferring with CursorMoved/VimEnter
    config = function()
      require('match-up').setup({
        text_obj = {
          enabled = 1,
          linewise_operators = {},
        },
        -- Use Neovim's built-in treesitter for %, highlighting, and textobjects
        treesitter = {
          enabled = true,
          disabled = {},
          disable_virtual_text = false,
          enable_quotes = true,
          stopline = 500,
          include_match_words = true,
        },
        matchparen = {
          deferred = 1,
          enabled = 1,
          hi_surround_always = 1,
          offscreen = { method = 'popup' },
          stopline = 400,
        },
        -- mini.surround handles ds%/cs%-style operations
        surround = { enabled = 0 },
      })
    end,
  },
  {
    'nvim-mini/mini.nvim',
    version = false,
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
              '[\'"`]()()[^%s\'"`]+()%s+()', -- First of multiple classnames
              '()%s+()[^%s\'"`]+()()[\'"`]', -- Last of multiple classnames
              '%s+()()[^%s\'"`]+()%s+()', -- Middle of multiple classnames
            },
          },
          -- Tag attribute textobject (for HTML/XML tags)
          -- Requires nvim-treesitter-textobjects plugin
          T = spec_treesitter({ a = '@attribute.outer', i = '@attribute.inner' }),
        },
      })
      require('mini.surround').setup()
      require('mini.splitjoin').setup()
      require('mini.comment').setup({
        options = {
          custom_commentstring = function()
            return require('ts_context_commentstring.internal').calculate_commentstring() or vim.bo.commentstring
          end,
        },
      })
      if not is_vscode then
        local hipatterns = require('mini.hipatterns')
        hipatterns.setup({
          highlighters = {
            fixme = { pattern = '%f[%w]()FIXME()%f[%W]', group = 'MiniHipatternsFixme' },
            hack = { pattern = '%f[%w]()HACK()%f[%W]', group = 'MiniHipatternsHack' },
            todo = { pattern = '%f[%w]()TODO()%f[%W]', group = 'MiniHipatternsTodo' },
            note = { pattern = '%f[%w]()NOTE()%f[%W]', group = 'MiniHipatternsNote' },
            hex_color = hipatterns.gen_highlighter.hex_color(),
          },
        })
        require('mini.pairs').setup({
          -- modes = { command = true },
        })
        require('mini.notify').setup({})
        require('mini.input').setup({})
        require('mini.statusline').setup({
          content = {
            active = function()
              -- Get default active statusline sections
              local mode, mode_hl = MiniStatusline.section_mode({ trunc_width = 120 })
              local git = MiniStatusline.section_git({ trunc_width = 40 })
              local diff = MiniStatusline.section_diff({ trunc_width = 75 })
              local diagnostics = MiniStatusline.section_diagnostics({ trunc_width = 75 })
              local lsp = MiniStatusline.section_lsp({ trunc_width = 75 })
              local filename = MiniStatusline.section_filename({ trunc_width = 140 })
              local fileinfo = MiniStatusline.section_fileinfo({ trunc_width = 120 })
              local location = MiniStatusline.section_location({ trunc_width = 75 })
              local search = MiniStatusline.section_searchcount({ trunc_width = 75 })

              -- --- Limit Git branch name length ---
              local max_length = 15 -- Set your max branch length here

              -- Extract just the branch name from the git string (e.g., "  branch-name")
              local branch_name = git:match('%s*(.*)')
              if branch_name and #branch_name > max_length then
                -- Truncate and add ellipsis
                git = string.format('  %s…', string.sub(branch_name, 1, max_length))
              end
              -- ------------------------------------

              -- Return the composed statusline
              return MiniStatusline.combine_groups({
                { hl = mode_hl, strings = { mode } },
                { hl = 'MiniStatuslineDevinfo', strings = { git, diff, diagnostics, lsp } },
                '%<', -- Mark general truncate point
                { hl = 'MiniStatuslineFilename', strings = { filename } },
                '%=', -- End left alignment
                { hl = 'MiniStatuslineFileinfo', strings = { fileinfo } },
                { hl = mode_hl, strings = { search, location } },
              })
            end,
          },
        })
      end
    end,
  },
  {
    'actionshrimp/direnv.nvim',
    opts = {
      -- async = true,
      -- on_direnv_finished = function()
      --   vim.cmd("LspStart")
      -- end
    },
  },
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
    'stevearc/quicker.nvim',
    cond = not is_vscode,
    event = 'VeryLazy',
    config = function()
      vim.keymap.set('n', '<leader>lq', function() require('quicker').toggle() end, {
        desc = 'Toggle quickfix',
      })
      vim.keymap.set('n', '<leader>ll', function() require('quicker').toggle({ loclist = true }) end, {
        desc = 'Toggle loclist',
      })
      require('quicker').setup({
        keys = {
          {
            '>',
            function() require('quicker').expand({ before = 2, after = 2, add_to_existing = true }) end,
            desc = 'Expand quickfix context',
          },
          {
            '<',
            function() require('quicker').collapse() end,
            desc = 'Collapse quickfix context',
          },
        },
      })
    end,
  },
  {
    'mikavilpas/yazi.nvim',
    version = '*',
    cond = not is_vscode,
    event = 'VeryLazy',
    dependencies = {
      { 'nvim-lua/plenary.nvim', lazy = true },
    },
    opts = {},
    config = function(_, opts)
      require('yazi').setup(opts)
      vim.keymap.set('n', '<leader>fy', '<cmd>Yazi<cr>', { desc = 'Yazi at current file' })
      vim.keymap.set('n', '<leader>fd', '<cmd>Yazi cwd<cr>', { desc = 'Yazi cwd' })
    end,
  },
  {
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

      require('plugins.telescope.multigrep').setup()
      -- vim.keymap.set({ 'n' }, '<leader>jg', function()
      --   builtin.live_grep()
      -- end, { desc = 'Find within files' })
      -- vim.keymap.set({ 'v' }, '<leader>jg', function()
      --   local query = vim.fn.escape(get_selection(), [[\/.*$^~[()]])
      --   builtin.live_grep({
      --     default_text = query,
      --   })
      -- end, { desc = 'Find within files' })

      vim.keymap.set('n', '<leader>jv', function() builtin.resume() end, { desc = 'Resume last Telescope' })
      vim.keymap.set('n', '<leader>ja', function() builtin.lsp_workspace_symbols() end, { desc = 'Workspace symbols' })
      vim.keymap.set(
        'n',
        '<leader>k',
        function()
          builtin.buffers({
            sort_mru = true,
            ignore_current_buffer = true,
          })
        end,
        { desc = 'Buffers MRU' }
      )
      -- vim.keymap.set('n', '<leader>,', function() builtin.buffers() end, { desc = 'All editors / buffers' })
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
          builtin.lsp_references()({
            default_text = get_selection(),
          })
        end,
        { desc = 'LSP references' }
      )
    end,
  },
  {
    'barrettruth/diffs.nvim',
    cond = not is_vscode,
    -- diffs.nvim lazy-loads itself; do not add event/ft/config/keys here
    init = function()
      vim.g.diffs = {
        integrations = {
          gitsigns = true,
        },
      }
    end,
  },
  {
    'pwntester/octo.nvim',
    cmd = 'Octo',
    cond = not is_vscode,
    dependencies = {
      'nvim-lua/plenary.nvim',
      'nvim-telescope/telescope.nvim',
      'nvim-tree/nvim-web-devicons',
    },
    opts = {
      picker = 'telescope',
    },
    config = function()
      require('octo').setup({
        picker = 'telescope',
        enable_builtin = true,
        use_local_fs = true,
      })
      pcall(require('telescope').load_extension, 'octo')
      vim.keymap.set('n', '<leader>o', '<cmd>Octo<cr>', { desc = 'Octo picker' })
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
  -- {
  --   'BlinkResearchLabs/blink-edit.nvim',
  --   enabled = not is_vscode,
  --   config = function()
  --     require('blink-edit').setup({
  --       llm = {
  --         provider = 'sweep',
  --         backend = 'openai',
  --         url = 'http://127.0.0.1:9292',
  --         model = 'sweep-next-edit:1.5b-q8',
  --       },
  --       ui = {
  --         progress = false,
  --         context = {
  --           history = {
  --             enabled = false,  -- Include recent edit history
  --             max_items = 5,    -- Number of history entries
  --             max_tokens = 512, -- Token budget for history
  --             max_files = 2,    -- Max files in history
  --             global = true,    -- Share history across buffers
  --           },
  --         },
  --       },
  --     })
  --   end,
  -- },
  {
    'cursortab/cursortab.nvim',
    cond = not is_vscode,
    -- cond = false,
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
  },
  {
    'neovim/nvim-lspconfig',
    config = function()
      vim.api.nvim_create_autocmd('LspAttach', {
        callback = function(args)
          local client = vim.lsp.get_client_by_id(args.data.client_id)
          if client and (client.name == 'ts_ls' or client.name == 'tsgo') then
            client.server_capabilities.documentFormattingProvider = false
            client.server_capabilities.documentRangeFormattingProvider = false
          end
          vim.keymap.set('n', 'gd', vim.lsp.buf.definition, { buffer = args.buf, remap = false })
        end,
      })
      vim.lsp.enable('stylua')
      vim.lsp.enable('lua_ls')
      vim.lsp.enable('nixd')
      vim.lsp.enable('biome')
      vim.lsp.enable('tailwindcss', { autostart = false })
      -- vim.lsp.enable('tsgo')
      vim.lsp.enable('ts_ls')
      vim.lsp.enable('zls')
      vim.lsp.enable('yamlls')
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
    'not-manu/filemention.nvim',
    cond = not is_vscode,
    event = 'InsertEnter',
    dependencies = {
      {
        'dmtrKovalenko/fff.nvim',
        build = function() require('fff.download').download_or_build_binary() end,
      },
    },
    opts = { finder = 'fff' },
  },
  {
    '3rd/image.nvim',
    cond = not is_vscode,
    build = false,
    opts = {
      processor = 'magick_rock',
      backend = 'kitty',
      integrations = {
        markdown = {
          enabled = true,
          download_remote_images = true,
          only_render_image_at_cursor = false,
        },
      },
    },
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
        use_nvim_cmp_as_default = true,
      },

      completion = {
        documentation = { auto_show = true, auto_show_delay_ms = 500 },
        list = { selection = { preselect = true, auto_insert = false } },
        keyword = { range = 'full' },
      },

      -- Default list of enabled providers defined so that you can extend it
      -- elsewhere in your config, without redefining it, due to `opts_extend`
      sources = {
        default = { 'filemention', 'lsp', 'path', 'snippets', 'buffer' },
        providers = {
          filemention = {
            name = 'filemention',
            module = 'filemention.sources.blink',
            override = {
              -- upstream execute tracks frecency but skips default accept impl
              execute = function(_source, _ctx, item, callback, default_implementation)
                local data = item.data
                if data and data.path then
                  require('filemention.files').track_access(
                    require('filemention.config').options,
                    data.path,
                    data.is_dir
                  )
                end
                default_implementation()
                callback()
              end,
            },
          },
        },
      },

      fuzzy = { implementation = 'prefer_rust_with_warning' },
    },
    opts_extend = { 'sources.default' },
  },
  {
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
  },
  {
    'JoosepAlviste/nvim-ts-context-commentstring',
    opts = {
      enable_autocmd = false,
    },
  },
  { 'akinsho/git-conflict.nvim', version = '*', config = true },
  {
    'akinsho/bufferline.nvim',
    version = '*',
    dependencies = 'nvim-tree/nvim-web-devicons',
    config = function()
      require('bufferline').setup({
        options = {
          mode = 'tabs',
        },
      })
    end,
  },
  {
    'rachartier/tiny-code-action.nvim',
    event = 'LspAttach',
    dependencies = {
      { 'nvim-telescope/telescope.nvim' },
    },
    opts = {
      backend = 'delta',
      picker = 'telescope',
      backend_opts = {
        delta = {
          header_lines_to_remove = 4,
          args = {
            '--line-numbers',
          },
        },
      },
      resolve_timeout = 100,
      notify = {
        enabled = true,
        on_empty = true,
      },
      signs = {
        quickfix = { '', { link = 'DiagnosticWarning' } },
        others = { '', { link = 'DiagnosticWarning' } },
        refactor = { '', { link = 'DiagnosticInfo' } },
        ['refactor.move'] = { '󰪹', { link = 'DiagnosticInfo' } },
        ['refactor.extract'] = { '', { link = 'DiagnosticError' } },
        ['source.organizeImports'] = { '', { link = 'DiagnosticWarning' } },
        ['source.fixAll'] = { '󰃢', { link = 'DiagnosticError' } },
        ['source'] = { '', { link = 'DiagnosticError' } },
        ['rename'] = { '󰑕', { link = 'DiagnosticWarning' } },
        ['codeAction'] = { '', { link = 'DiagnosticWarning' } },
      },
    },
    config = function()
      vim.keymap.set(
        { 'n', 'x' },
        '<leader>ca',
        function() require('tiny-code-action').code_action({}) end,
        { noremap = true, silent = true }
      )
    end,
  },
  {
    'rachartier/tiny-inline-diagnostic.nvim',
    event = 'VeryLazy',
    priority = 1000,
    config = function()
      require('tiny-inline-diagnostic').setup({
        options = {
          multilines = {
            enabled = true,
          },
          show_source = {
            enabled = true,
          },
          override_open_float = true,
        },
      })
      vim.diagnostic.config({ virtual_text = false }) -- Disable Neovim's default virtual text diagnostics
    end,
  },
})
