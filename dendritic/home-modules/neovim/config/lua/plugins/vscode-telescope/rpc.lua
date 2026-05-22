local M = {}

local log = require('plugins.vscode-telescope.log')
local paths = require('plugins.vscode-telescope.paths')

local function run_cmd(args)
  local cmd = table.concat(args, ' ')
  log.debug('rpc_cmd', { cmd = cmd })

  local handle = io.popen(cmd .. ' 2>&1', 'r')
  if not handle then
    return { code = 1, stdout = '', stderr = 'io.popen failed' }
  end

  local output = handle:read('*a') or ''
  local ok, _, code = handle:close()

  return {
    code = ok and (code or 0) or (code or 1),
    stdout = output,
    stderr = '',
  }
end

local function remote_lua(code, args)
  args = args or {}
  local arg_list = {}
  for _, value in ipairs(args) do
    arg_list[#arg_list + 1] = vim.fn.string(value)
  end

  return string.format(
    'luaeval("package.loaded[\\"plugins.vscode-telescope.sidecar\\"]=nil; %s", [%s])',
    code,
    table.concat(arg_list, ', ')
  )
end

function M.socket_exists()
  return vim.loop.fs_stat(paths.socket_path()) ~= nil
end

function M.ready_exists()
  return vim.loop.fs_stat(paths.ready_path()) ~= nil
end

function M.ready_version()
  if not M.ready_exists() then
    return nil
  end

  local lines = vim.fn.readfile(paths.ready_path())
  return tonumber(lines[3])
end

function M.ready_version_matches()
  local version = M.ready_version()
  return version ~= nil and version >= paths.BRIDGE_VERSION
end

function M.ready_pid()
  if not M.ready_exists() then
    return nil
  end

  local lines = vim.fn.readfile(paths.ready_path())
  return tonumber(lines[1])
end

function M.ping()
  local socket = paths.socket_path()

  if not M.socket_exists() then
    return false, 'socket missing'
  end

  if M.ready_exists() and M.ready_version_matches() then
    return true, 'ready marker'
  end

  local result = run_cmd({
    vim.fn.shellescape(vim.v.progpath),
    '--server',
    vim.fn.shellescape(socket),
    '--remote-expr',
    vim.fn.string(
      string.format(
        'exists("g:vscode_telescope_ready") == 1 && g:vscode_telescope_ready == v:true && exists("g:vscode_telescope_bridge_version") == 1 && g:vscode_telescope_bridge_version >= %d',
        paths.BRIDGE_VERSION
      )
    ),
  })

  local stdout = vim.trim(result.stdout or '')
  local ok = result.code == 0 and stdout == '1'

  log.info('rpc_ping', {
    ok = ok,
    code = result.code,
    stdout = stdout,
    reason = ok and 'remote-expr' or 'not ready',
    version = M.ready_version(),
  })

  return ok, stdout
end

function M.close_pickers()
  if not M.socket_exists() then
    return false, 'socket missing'
  end

  local result = run_cmd({
    vim.fn.shellescape(vim.v.progpath),
    '--server',
    vim.fn.shellescape(paths.socket_path()),
    '--remote-expr',
    vim.fn.string(remote_lua('require(\\"plugins.vscode-telescope.sidecar\\").close_pickers()')),
  })

  log.info('rpc_close_pickers', {
    code = result.code,
    stdout = vim.trim(result.stdout or ''),
  })

  return result.code == 0, result
end

function M.dispatch(request_path)
  local result = run_cmd({
    vim.fn.shellescape(vim.v.progpath),
    '--server',
    vim.fn.shellescape(paths.socket_path()),
    '--remote-expr',
    vim.fn.string(remote_lua('require(\\"plugins.vscode-telescope.sidecar\\").run_request(_A[1])', { request_path })),
  })

  log.info('rpc_dispatch', {
    request_path = request_path,
    code = result.code,
    stdout = vim.trim(result.stdout or ''),
  })

  return result.code == 0, result
end

function M.dispatch_async(request_path, callback)
  local socket = paths.socket_path()

  log.info('rpc_dispatch_async', { request_path = request_path, socket = socket })

  vim.fn.jobstart({
    vim.v.progpath,
    '--server',
    socket,
    '--remote-expr',
    remote_lua('require(\\"plugins.vscode-telescope.sidecar\\").run_request(_A[1])', { request_path }),
  }, {
    on_exit = function(_, code)
      log.info('rpc_dispatch_async_done', { request_path = request_path, code = code })
      if callback then
        callback(code == 0, code)
      end
    end,
  })
end

function M.clear_ready()
  pcall(vim.fn.delete, paths.ready_path())
end

function M.write_ready()
  local version = vim.g.vscode_telescope_bridge_version or paths.BRIDGE_VERSION
  vim.fn.writefile({
    tostring(vim.fn.getpid()),
    tostring(os.time()),
    tostring(version),
  }, paths.ready_path())
end

return M
