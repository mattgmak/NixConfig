local is_vscode = vim.g.vscode ~= nil

return {
  'saghen/blink.cmp',
  cond = not is_vscode,
  branch = 'v1',
  version = '1.*',
  ---@module 'blink.cmp'
  ---@type blink.cmp.Config
  opts = {
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
    sources = {
      default = { 'filemention', 'lsp', 'path', 'snippets', 'buffer' },
      per_filetype = {
        ['pi-prompt'] = { 'pi' },
      },
      providers = {
        pi = {
          name = 'pi',
          module = 'pi-bridge.blink_source',
        },
        filemention = {
          name = 'filemention',
          module = 'filemention.sources.blink',
          override = {
            execute = function(_source, _ctx, item, callback, default_implementation)
              local data = item.data
              if data and data.path then
                require('filemention.files').track_access(require('filemention.config').options, data.path, data.is_dir)
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
}
