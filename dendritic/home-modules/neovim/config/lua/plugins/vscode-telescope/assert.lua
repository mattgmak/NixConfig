local log = require('plugins.vscode-telescope.log')

local M = {}

function M.check(cond, msg, ctx)
  if cond then
    return true
  end

  log.error('assert_failed', {
    msg = msg,
    ctx = ctx or {},
  })

  if log.strict() then
    error('vscode-telescope assert: ' .. msg)
  end

  return false
end

function M.not_nil(value, name, ctx)
  return M.check(value ~= nil and value ~= vim.NIL, name .. ' must not be nil', ctx)
end

function M.is_true(value, name, ctx)
  return M.check(value == true, name .. ' must be true', ctx)
end

function M.file_readable(path, name, ctx)
  return M.check(path and path ~= '' and vim.fn.filereadable(path) == 1, name .. ' must be readable: ' .. tostring(path), ctx)
end

function M.one_of(value, allowed, name, ctx)
  for _, item in ipairs(allowed) do
    if value == item then
      return true
    end
  end
  return M.check(false, name .. ' must be one of ' .. vim.inspect(allowed) .. ', got ' .. tostring(value), ctx)
end

return M
