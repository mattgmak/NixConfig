local assert_mod = require('plugins.vscode-telescope.assert')

local M = {}

function M.read_json(path)
  assert_mod.check(path and path ~= '', 'json path required', { path = path })
  if vim.fn.filereadable(path) ~= 1 then
    return nil
  end
  local lines = vim.fn.readfile(path)
  if #lines == 0 then
    return nil
  end
  local ok, decoded = pcall(vim.json.decode, lines[1])
  if not ok then
    return nil
  end
  return decoded
end

function M.write_json(path, value)
  assert_mod.not_nil(path, 'json path')
  assert_mod.not_nil(value, 'json value')
  vim.fn.writefile({ vim.json.encode(value) }, path)
end

return M
