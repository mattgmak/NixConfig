-- Minimal config for the nvim instance Firenvim starts; skips lazy_setup.lua.
vim.g.mapleader = ' '
vim.g.maplocalleader = ','

vim.opt.clipboard = 'unnamedplus'
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.undofile = true
vim.opt.undodir = vim.fn.stdpath('data') .. '/firenvim-undo'
vim.o.number = true
vim.o.relativenumber = true

vim.keymap.set('n', '<leader>w', '<cmd>w<cr>', { silent = true, desc = 'Save' })
vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<cr>', { silent = true })
vim.keymap.set('n', 'U', '<C-r>')
vim.keymap.set('v', 'p', 'P')
vim.keymap.set('n', 'c', '"_c', { noremap = true })
vim.keymap.set('n', 'C', '"_C', { noremap = true })
vim.keymap.set('n', 'x', '"_x', { noremap = true })

vim.g.firenvim_config = {
  globalSettings = {},
  localConfig = {
    ['.*'] = {
      selector = 'textarea, input:not([type]), input[type=text], input[type=search], input[type=email], input[type=url], input[type=tel], input[type=number], [contenteditable]',
      takeover = 'always',
      mode = 'insert',
    },
  },
}

local root = vim.fn.stdpath('data') .. '/firenvim'
local lazypath = root .. '/lazy/lazy.nvim'
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local out = vim.fn.system({
    'git',
    'clone',
    '--filter=blob:none',
    '--branch=stable',
    'https://github.com/folke/lazy.nvim.git',
    lazypath,
  })
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

require('lazy').setup({
  spec = {
    { 'glacambre/firenvim', lazy = false },
    {
      'leap.nvim',
      url = 'https://codeberg.org/andyg/leap.nvim',
      lazy = false,
      config = function()
        vim.keymap.set({ 'n', 'x', 'o' }, '<BS>', '<Plug>(leap)')
        vim.keymap.set({ 'n', 'x', 'o' }, 'gh', '<Plug>(leap)')
        vim.keymap.set({ 'n' }, '<leader><BS>', '<Plug>(leap-anywhere)')
        vim.keymap.set({ 'n' }, '<leader>gh', '<Plug>(leap-anywhere)')
        vim.keymap.set({ 'n', 'o' }, 'gs', function()
          require('leap.remote').action({
            input = vim.fn.mode(true):match('o') and '' or 'v',
          })
        end)

        require('leap').opts.preview = function(ch0, ch1, ch2)
          return not (ch1:match('%s') or (ch0:match('%a') and ch1:match('%a') and ch2:match('%a')))
        end

        require('leap').opts.on_beacons = function(targets, _, _)
          for _, t in ipairs(targets) do
            if t.label and t.beacon then t.beacon[1] = 0 end
          end
        end

        vim.api.nvim_set_hl(0, 'LeapBackdrop', { link = 'Comment' })
      end,
    },
    {
      'nvim-mini/mini.nvim',
      version = false,
      lazy = false,
      config = function()
        require('mini.surround').setup()
        require('mini.ai').setup()
        require('mini.pairs').setup({})
        require('mini.comment').setup()
        require('mini.statusline').setup({
          content = {
            active = function()
              local mode, mode_hl = MiniStatusline.section_mode({ trunc_width = 120 })
              local location = MiniStatusline.section_location({ trunc_width = 75 })
              local search = MiniStatusline.section_searchcount({ trunc_width = 75 })
              return MiniStatusline.combine_groups({
                { hl = mode_hl, strings = { mode } },
                '%=',
                { hl = mode_hl, strings = { search, location } },
              })
            end,
          },
        })
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
          install_dir = vim.fn.stdpath('data') .. '/firenvim-site',
        })
        ts.install({
          'markdown',
          'markdown_inline',
          'html',
          'javascript',
          'typescript',
          'json',
          'lua',
        }):wait(300000)
        vim.api.nvim_create_autocmd('FileType', {
          pattern = { '<filetype>' },
          callback = function() vim.treesitter.start() end,
        })
        vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
      end,
    },
    {
      'nvim-treesitter/nvim-treesitter-textobjects',
      branch = 'main',
      config = function()
        local select = require('nvim-treesitter-textobjects.select')
        require('nvim-treesitter-textobjects').setup({
          select = {
            lookahead = true,
            selection_modes = {
              ['@parameter.outer'] = 'v',
              ['@function.outer'] = 'V',
            },
          },
        })
        vim.keymap.set({ 'x', 'o' }, 'af', function()
          select.select_textobject('@function.outer', 'textobjects')
        end)
        vim.keymap.set({ 'x', 'o' }, 'if', function()
          select.select_textobject('@function.inner', 'textobjects')
        end)
        vim.keymap.set({ 'x', 'o' }, 'a#', function()
          select.select_textobject('@comment.outer', 'textobjects')
        end)
        vim.keymap.set({ 'x', 'o' }, 'i#', function()
          select.select_textobject('@comment.inner', 'textobjects')
        end)
      end,
    },
    {
      'andymass/vim-matchup',
      lazy = false,
      config = function()
        require('match-up').setup({
          text_obj = {
            enabled = 1,
            linewise_operators = {},
          },
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
          surround = { enabled = 0 },
        })
      end,
    },
  },
  root = root .. '/lazy',
  lockfile = vim.fn.stdpath('config') .. '/firenvim-lock.json',
  checker = { enabled = false },
  change_detection = { notify = false },
})
