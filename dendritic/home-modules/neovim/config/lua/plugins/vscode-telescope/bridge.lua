local M = {}

local assert_mod = require('plugins.vscode-telescope.assert')
local json = require('plugins.vscode-telescope.json')
local log = require('plugins.vscode-telescope.log')
local rpc = require('plugins.vscode-telescope.rpc')
local terminal = require('plugins.vscode-telescope.terminal')
local vscode_actions = require('plugins.vscode-telescope.vscode_actions')

local pending = false

function M.ping()
  local ok, detail = rpc.ping()
  log.debug('ping', { ok = ok, detail = detail, socket = terminal.socket_path() })
  return ok
end

local function wait_for_sidecar(tries, cb)
  log.debug('wait_for_sidecar', { tries = tries, socket = terminal.socket_path(), ready = rpc.ready_exists() })

  local ok = M.ping()
  if ok then
    cb(true)
    return
  end

  if tries <= 0 then
    log.error('wait_for_sidecar_timeout', {
      socket_exists = rpc.socket_exists(),
      ready_exists = rpc.ready_exists(),
    })
    cb(false)
    return
  end

  vim.defer_fn(function()
    wait_for_sidecar(tries - 1, cb)
  end, 250)
end

local function wait_for_result(result_path, tries, cb)
  local result = json.read_json(result_path)
  if result then
    log.info('result_ready', { result_path = result_path, result = result })
    cb(result)
    return
  end

  if tries <= 0 then
    log.error('wait_for_result_timeout', {
      result_path = result_path,
      sidecar_ready = rpc.ready_exists(),
      socket_exists = rpc.socket_exists(),
    })
    cb({ cancelled = true, error = 'timed out waiting for picker result' })
    return
  end

  if tries % 20 == 0 then
    log.debug('wait_for_result_poll', { result_path = result_path, tries = tries })
  end

  vim.defer_fn(function()
    wait_for_result(result_path, tries - 1, cb)
  end, 150)
end

local function finish(request_path, result_path, result)
  log.info('finish', {
    request_path = request_path,
    result_path = result_path,
    cancelled = result.cancelled,
    error = result.error,
    picker = result.picker,
    path = result.path,
  })

  if result.error then
    require('vscode').notify('Telescope bridge: ' .. result.error, vim.log.levels.ERROR)
  end
  if not result.cancelled then
    vscode_actions.apply(result)
  end
  terminal.restore_panel()
  pcall(vim.fn.delete, request_path)
  pcall(vim.fn.delete, result_path)
  pending = false
end

function M.ensure_sidecar(request_path, cb)
  assert_mod.file_readable(request_path, 'request file', { stage = 'ensure_sidecar' })

  if M.ping() then
    log.info('ensure_sidecar_reuse', { request_path = request_path })
    cb(true, false)
    return
  end

  if rpc.socket_exists() or rpc.ready_exists() then
    log.info('ensure_sidecar_restart_stale', {
      request_path = request_path,
      ready_version = rpc.ready_version(),
      expected_version = require('plugins.vscode-telescope.paths').BRIDGE_VERSION,
    })
    terminal.kill_sidecar()
  end

  log.info('ensure_sidecar_spawn', { request_path = request_path })
  rpc.clear_ready()
  terminal.write_pending_request(request_path)
  assert_mod.file_readable(terminal.pending_request_path(), 'pending request marker')

  terminal.spawn_sidecar(function()
    wait_for_sidecar(120, function(ok)
      log.info('ensure_sidecar_ready', { ok = ok, spawned = ok })
      cb(ok, ok)
    end)
  end)
end

function M.run_picker(picker, opts)
  if pending then
    log.warn('run_picker_busy', { picker = picker })
    require('vscode').notify('Telescope bridge busy', vim.log.levels.WARN)
    return
  end

  pending = true
  opts = opts or {}
  log.new_session()

  assert_mod.one_of(
    picker,
    { 'find_files', 'current_buffer_fuzzy_find', 'multigrep', 'pickers', 'resume', 'builtin', 'help_tags' },
    'picker'
  )

  local request_path = vim.fn.tempname() .. '.json'
  local result_path = vim.fn.tempname() .. '.json'

  local request = {
    picker = picker,
    opts = opts.opts or {},
    file = opts.file,
    result_path = result_path,
  }

  if opts.default_text and opts.default_text ~= '' then
    request.opts.default_text = opts.default_text
  end

  json.write_json(request_path, request)
  log.info('run_picker_start', {
    picker = picker,
    request_path = request_path,
    result_path = result_path,
    file = opts.file,
    default_text = opts.default_text,
  })

  terminal.maximize_panel()

  M.ensure_sidecar(request_path, function(ok, spawned)
    if not ok then
      pending = false
      pcall(vim.fn.delete, request_path)
      pcall(vim.fn.delete, result_path)
      log.error('run_picker_sidecar_failed', { picker = picker })
      require('vscode').notify('Telescope sidecar failed to start', vim.log.levels.ERROR)
      return
    end

    if spawned then
      log.info('run_picker_pending_boot', { request_path = request_path })
    else
      log.info('run_picker_dispatch', { request_path = request_path })
      rpc.close_pickers()
      rpc.dispatch_async(request_path)
    end

    wait_for_result(result_path, 600, function(result)
      finish(request_path, result_path, result)
    end)
  end)
end

return M
