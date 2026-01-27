local is_vscode = vim.g.vscode ~= nil
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

-- TODO: move off lazy
-- Setup lazy.nvim
require('lazy').setup({
  {
    'vscode-neovim/vscode-multi-cursor.nvim',
    event = 'VeryLazy',
    cond = is_vscode,
    opts = {},
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
    enabled = true,
    config = function(_, opts)
      vim.keymap.set({ 'n', 'x', 'o' }, '<BS>', '<Plug>(leap)')
      vim.keymap.set({ 'n' }, '<leader><BS>', '<Plug>(leap-from-window)')
      -- vim.keymap.set({ 'n', 'o' }, 'gs', function()
      vim.keymap.set({ 'n', 'o' }, 'h', function()
        require('leap.remote').action({
          -- Automatically enter Visual mode when coming from Normal.
          input = vim.fn.mode(true):match('o') and '' or 'v',
        })
      end)
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
  },
  {
    'echasnovski/mini.nvim',
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
              '[\'"`]()()[^%s\'"`]+()%s+()', -- First of multiple classnames
              '%s+()()[^%s\'"`]+()()[\'"`]', -- Last of multiple classnames
              '%s+()()[^%s\'"`]+()%s+()', -- Middle of multiple classnames
            },
          },
          -- Tag attribute textobject (for HTML/XML tags)
          -- Requires nvim-treesitter-textobjects plugin
          T = spec_treesitter({ a = '@attribute.outer', i = '@attribute.inner' }),
        },
      })
      require('mini.surround').setup()
    end,
  },
})
