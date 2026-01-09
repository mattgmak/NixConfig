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
    'ggandor/leap.nvim',
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
    end,
  },
  {
    'echasnovski/mini.nvim',
    version = '*',
    config = function()
      local gen_ai_spec = require('mini.extra').gen_ai_spec
      require('mini.ai').setup({
        custom_textobjects = {
          B = gen_ai_spec.buffer(),
          D = gen_ai_spec.diagnostic(),
          I = gen_ai_spec.indent(),
          L = gen_ai_spec.line(),
          N = gen_ai_spec.number(),
        },
      })
      require('mini.surround').setup()
    end,
  },
})
