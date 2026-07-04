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
    vim.lsp.config('tailwindcss', {
      settings = {
        tailwindCSS = {
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
    vim.lsp.enable('tsgo')
    vim.lsp.enable('tailwindcss')
    vim.lsp.enable('zls')
    vim.lsp.enable('yamlls')
  end,
}
