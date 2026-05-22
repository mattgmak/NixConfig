local M = {}

function M.enabled()
  if vim.g.vscode_telescope_debug == false then
    return false
  end
  if vim.g.vscode_telescope_sidecar then
    return true
  end
  if vim.g.vscode_telescope_debug == true then
    return true
  end
  local env = os.getenv('VSCODE_TELESCOPE_DEBUG')
  return env == '1' or env == 'true'
end

function M.strict()
  return vim.g.vscode_telescope_debug_strict == true
end

local paths = require('plugins.vscode-telescope.paths')

function M.log_path()
  return paths.log_path()
end

function M.role()
  if vim.g.vscode then
    return 'embedded'
  end
  if vim.g.vscode_telescope_sidecar then
    return 'sidecar'
  end
  return 'nvim'
end

function M.session_id()
  if not vim.g.vscode_telescope_session then
    vim.g.vscode_telescope_session = tostring(os.time()) .. '-' .. tostring(math.random(1000, 9999))
  end
  return vim.g.vscode_telescope_session
end

function M.new_session()
  vim.g.vscode_telescope_session = tostring(os.time()) .. '-' .. tostring(math.random(1000, 9999))
  return vim.g.vscode_telescope_session
end

local function encode(value)
  if type(value) == 'table' then
    local ok, json = pcall(vim.json.encode, value)
    if ok then
      return json
    end
  end
  return vim.inspect(value)
end

local function write_line(level, event, data)
  if not M.enabled() then
    return
  end

  local dir = vim.fn.stdpath('data') .. '/vscode-telescope'
  vim.fn.mkdir(dir, 'p')

  local record = {
    ts = os.date('!%Y-%m-%dT%H:%M:%SZ'),
    level = level,
    role = M.role(),
    session = vim.g.vscode_telescope_session,
    event = event,
    data = data,
  }

  local ok, line = pcall(vim.json.encode, record)
  if not ok then
    line = string.format(
      '{"level":"%s","event":"%s","fallback":"%s"}',
      level,
      event,
      encode(data)
    )
  end

  local path = M.log_path()
  local fd = io.open(path, 'a')
  if fd then
    fd:write(line .. '\n')
    fd:close()
  end

  if level == 'error' or level == 'warn' then
    local msg = string.format('[vscode-telescope:%s] %s', event, encode(data))
    if vim.g.vscode then
      pcall(function()
        require('vscode').notify(msg, level == 'error' and vim.log.levels.ERROR or vim.log.levels.WARN)
      end)
    else
      vim.notify(msg, level == 'error' and vim.log.levels.ERROR or vim.log.levels.WARN)
    end
  end
end

function M.debug(event, data)
  write_line('debug', event, data)
end

function M.info(event, data)
  write_line('info', event, data)
end

function M.warn(event, data)
  write_line('warn', event, data)
end

function M.error(event, data)
  write_line('error', event, data)
end

function M.clear()
  local path = M.log_path()
  pcall(vim.fn.delete, path)
  M.info('log_cleared', { path = path })
end

function M.tail(n)
  n = n or 40
  local path = M.log_path()
  if vim.fn.filereadable(path) ~= 1 then
    return {}
  end
  local lines = vim.fn.readfile(path)
  if #lines <= n then
    return lines
  end
  local out = {}
  for i = #lines - n + 1, #lines do
    out[#out + 1] = lines[i]
  end
  return out
end

return M
