return {
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
}
