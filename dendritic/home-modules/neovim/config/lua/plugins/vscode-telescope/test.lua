local assert_mod = require('plugins.vscode-telescope.assert')
local json = require('plugins.vscode-telescope.json')
local log = require('plugins.vscode-telescope.log')
local paths = require('plugins.vscode-telescope.paths')

local M = {}

local function test(name, fn)
  local ok, err = pcall(fn)
  if ok then
    log.info('test_pass', { name = name })
    return true, nil
  end
  log.error('test_fail', { name = name, err = tostring(err) })
  return false, err
end

function M.run()
  vim.g.vscode_telescope_debug = true
  log.clear()
  log.info('test_run_start', { role = log.role() })

  local results = {}
  local passed = 0
  local failed = 0

  local cases = {
    log_path_exists = function()
      local path = log.log_path()
      assert_mod.check(path:match('vscode%-telescope/debug%.log$') ~= nil, 'log path suffix', { path = path })
    end,
    json_roundtrip = function()
      local path = vim.fn.tempname() .. '.json'
      local payload = { picker = 'find_files', opts = { default_text = 'foo' }, n = 1 }
      json.write_json(path, payload)
      assert_mod.file_readable(path, 'json file')
      local decoded = json.read_json(path)
      assert_mod.check(decoded.picker == 'find_files', 'picker roundtrip')
      assert_mod.check(decoded.opts.default_text == 'foo', 'opts roundtrip')
      pcall(vim.fn.delete, path)
    end,
    assert_check_pass = function()
      assert_mod.check(true, 'should pass')
    end,
    assert_check_fail_soft = function()
      vim.g.vscode_telescope_debug_strict = false
      local ok = assert_mod.check(false, 'expected soft fail')
      assert_mod.check(ok == false, 'soft assert returns false')
    end,
    ready_path = function()
      local path = paths.ready_path()
      assert_mod.check(path:match('%.ready$') ~= nil, 'ready suffix', { path = path })
    end,
    pending_request_path = function()
      local path = paths.pending_request_path()
      assert_mod.check(path:match('%.pending$') ~= nil, 'pending suffix', { path = path })
    end,
    socket_path = function()
      local path = paths.socket_path()
      assert_mod.check(path:match('vscode%-telescope%.sock$') ~= nil, 'socket suffix', { path = path })
    end,
  }

  for name, fn in pairs(cases) do
    local ok, err = test(name, fn)
    results[#results + 1] = { name = name, ok = ok, err = err and tostring(err) or nil }
    if ok then
      passed = passed + 1
    else
      failed = failed + 1
    end
  end

  log.info('test_run_done', { passed = passed, failed = failed, total = passed + failed })

  local summary = string.format('vscode-telescope tests: %d passed, %d failed (log: %s)', passed, failed, log.log_path())
  if vim.g.vscode then
    pcall(function()
      require('vscode').notify(summary, failed == 0 and vim.log.levels.INFO or vim.log.levels.ERROR)
    end)
  else
    vim.notify(summary, failed == 0 and vim.log.levels.INFO or vim.log.levels.ERROR)
  end

  return {
    passed = passed,
    failed = failed,
    results = results,
    log_path = log.log_path(),
  }
end

return M
