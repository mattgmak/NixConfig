local M = {}

local TS_FORMATTERS = {
  ts_ls = true,
  tsgo = true,
}

local SHELL_FTS = {
  sh = true,
  bash = true,
}

local function is_shell(bufnr)
  return SHELL_FTS[vim.bo[bufnr or 0].filetype] == true
end

local function format_shell(bufnr, async)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local stdin = (#lines > 0 and table.concat(lines, '\n') or '') .. '\n'
  local path = vim.api.nvim_buf_get_name(bufnr)

  -- shfmt(1): EditorConfig is automatic when no -i/-bn/... flags are passed.
  -- --filename is required for stdin so .editorconfig is found relative to the script.
  local cmd = { 'shfmt' }
  if path ~= '' then
    cmd[#cmd + 1] = '--filename'
    cmd[#cmd + 1] = path
  end
  cmd[#cmd + 1] = '-'

  local function apply(stdout)
    if not stdout or stdout == '' then
      return
    end
    local new_lines = vim.split(stdout, '\n', { plain = true })
    if new_lines[#new_lines] == '' then
      table.remove(new_lines)
    end
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, new_lines)
  end

  if async then
    vim.system(cmd, { stdin = stdin, text = true }, function(res)
      if res.code ~= 0 then
        vim.schedule(function()
          vim.notify('shfmt: ' .. (res.stderr ~= '' and res.stderr or 'format failed'), vim.log.levels.ERROR)
        end)
        return
      end
      vim.schedule(function() apply(res.stdout) end)
    end)
    return
  end

  local res = vim.system(cmd, { stdin = stdin, text = true }):wait()
  if res.code ~= 0 then
    vim.notify('shfmt: ' .. (res.stderr ~= '' and res.stderr or 'format failed'), vim.log.levels.ERROR)
    return
  end
  apply(res.stdout)
end

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

  -- shfmt reads .editorconfig automatically (no printer flags); see shfmt(1).
  if is_shell(bufnr) then
    format_shell(bufnr, opts.async)
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
