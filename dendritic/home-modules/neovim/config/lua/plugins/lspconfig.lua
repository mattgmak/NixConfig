return {
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
    vim.lsp.config('bashls', {
      settings = {
        bashIde = {
          shellcheckPath = 'shellcheck',
          shfmt = {
            path = 'shfmt',
          },
        },
      },
    })
    vim.lsp.enable('bashls')

    vim.lsp.config('tailwindcss', {
      settings = {
        tailwindCSS = {
          classFunctions = { 'cva', 'cn' },
          experimental = {
            classRegex = {
              "[a-zA-Z]*ClassName='([^']+)'",
              '[a-zA-Z]*ClassName="([^"]+)"',
              '[a-zA-Z]*ClassName={`([^`]+)`}',
            },
          },
        },
      },
    })
    vim.lsp.enable('tailwindcss')

    local tsc_major_cache = {}

    vim.lsp.config('tsgo', {
      cmd = function(dispatchers, config)
        local root = config and config.root_dir

        local function tsc_major_version(cmd)
          local key = vim.fn.exepath(cmd) or cmd
          if tsc_major_cache[key] ~= nil then return tsc_major_cache[key] end

          local result = vim.system({ cmd, '--version' }, { text = true }):wait()
          local major = 0
          if result.code == 0 then
            major = tonumber(result.stdout:match('Version (%d+)')) or 0
          end
          tsc_major_cache[key] = major
          return major
        end

        local function resolve(name)
          local cmd = name
          if root then
            local local_cmd = vim.fs.joinpath(root, 'node_modules/.bin', name)
            if vim.fn.executable(local_cmd) == 1 then cmd = local_cmd end
          end
          if vim.fn.executable(cmd) ~= 1 then return nil end
          if name == 'tsc' and tsc_major_version(cmd) < 7 then return nil end
          return cmd
        end

        for _, name in ipairs({ 'tsc', 'tsgo' }) do
          local cmd = resolve(name)
          if cmd then return vim.lsp.rpc.start({ cmd, '--lsp', '--stdio' }, dispatchers) end
        end

        vim.notify('No TS 7 LSP binary found (tried tsc, tsgo)', vim.log.levels.ERROR)
      end,
    })
    vim.lsp.enable('tsgo')

    vim.lsp.enable('zls')
    vim.lsp.enable('yamlls')
  end,
}
