local is_vscode = vim.g.vscode ~= nil

return {
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
        c = {
          { '%b""', "%b''", '%b``' },
          {
            '[\'"`]()()[^%s\'"`]+()()[\'"`]',
            '[\'"`]()()[^%s\'"`]+()%s+()',
            '()%s+()[^%s\'"`]+()()[\'"`]',
            '%s+()()[^%s\'"`]+()%s+()',
          },
        },
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
      require('mini.pairs').setup({})
      require('mini.notify').setup({})
      require('mini.input').setup({})
      require('mini.statusline').setup({
        content = {
          active = function()
            local mode, mode_hl = MiniStatusline.section_mode({ trunc_width = 120 })
            local git = MiniStatusline.section_git({ trunc_width = 40 })
            local diff = MiniStatusline.section_diff({ trunc_width = 75 })
            local diagnostics = MiniStatusline.section_diagnostics({ trunc_width = 75 })
            local lsp = MiniStatusline.section_lsp({ trunc_width = 75 })
            local filename = MiniStatusline.section_filename({ trunc_width = 140 })
            local fileinfo = MiniStatusline.section_fileinfo({ trunc_width = 120 })
            local location = MiniStatusline.section_location({ trunc_width = 75 })
            local search = MiniStatusline.section_searchcount({ trunc_width = 75 })

            local max_length = 15
            local branch_name = git:match('%s*(.*)')
            if branch_name and #branch_name > max_length then
              git = string.format('  %s…', string.sub(branch_name, 1, max_length))
            end

            return MiniStatusline.combine_groups({
              { hl = mode_hl, strings = { mode } },
              { hl = 'MiniStatuslineDevinfo', strings = { git, diff, diagnostics, lsp } },
              '%<',
              { hl = 'MiniStatuslineFilename', strings = { filename } },
              '%=',
              { hl = 'MiniStatuslineFileinfo', strings = { fileinfo } },
              { hl = mode_hl, strings = { search, location } },
            })
          end,
        },
      })
    end
  end,
}
