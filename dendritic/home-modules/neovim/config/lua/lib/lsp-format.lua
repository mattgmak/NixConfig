local M = {}

local TS_FORMATTERS = {
  ts_ls = true,
  tsgo = true,
}

local function has_biome(bufnr) return #vim.lsp.get_clients({ bufnr = bufnr or 0, name = 'biome' }) > 0 end

function M.format(opts)
  opts = opts or {}
  local bufnr = opts.bufnr or 0

  if has_biome(bufnr) then
    vim.lsp.buf.format({
      bufnr = bufnr,
      async = opts.async,
      range = opts.range,
      filter = function(client) return client.name == 'biome' end,
    })
    if opts.fix_all ~= false then
      vim.lsp.buf.code_action({
        bufnr = bufnr,
        context = { only = { 'source.fixAll.biome' } },
        apply = true,
      })
    end
    return
  end

  vim.lsp.buf.format({
    bufnr = bufnr,
    async = opts.async,
    range = opts.range,
    filter = function(client) return not TS_FORMATTERS[client.name] end,
  })
end

return M
