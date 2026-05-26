local M = {}

local NOTIFY_SOURCE = 'check-types'
local NOTIFY_DURATION = { INFO = 4000, WARN = 5000, ERROR = 8000 }

local function notify_add(msg, level, hl_group)
  if type(MiniNotify) == 'table' and MiniNotify.add then
    return MiniNotify.add(msg, level, hl_group, { source = NOTIFY_SOURCE })
  end
  vim.notify(msg, vim.log.levels[level])
  return nil
end

local function notify_update(id, msg, level, hl_group)
  if id and type(MiniNotify) == 'table' and MiniNotify.update then
    MiniNotify.update(id, { msg = msg, level = level, hl_group = hl_group })
    return
  end
  if msg then
    vim.notify(msg, vim.log.levels[level])
  end
end

local function notify_finish(id, msg, level, hl_group)
  notify_update(id, msg, level, hl_group)
  if id and type(MiniNotify) == 'table' and MiniNotify.remove then
    vim.defer_fn(function()
      MiniNotify.remove(id)
    end, NOTIFY_DURATION[level] or NOTIFY_DURATION.INFO)
  end
end

local function mono_root()
  local marker = vim.fs.find('pnpm-workspace.yaml', { upward = true })[1]
  return marker and vim.fn.fnamemodify(marker, ':h') or nil
end

local function pkg_roots(root)
  local roots = {}
  for _, manifest in ipairs(vim.fn.glob(root .. '/{apps,packages}/*/package.json', false, true)) do
    local lines = vim.fn.readfile(manifest)
    if #lines > 0 then
      local ok, data = pcall(vim.json.decode, table.concat(lines, '\n'))
      if ok and data.name then
        roots[data.name] = vim.fn.fnamemodify(manifest, ':h')
      end
    end
  end
  return roots
end

local function strip_ansi(line)
  return line:gsub('\27%[[0-9;]*[A-Za-z]', '')
end

function M.parse(lines, roots)
  local items = {}
  local last = nil

  for _, raw in ipairs(lines) do
    local line = strip_ansi(raw)
    local pkg, rel, lnum, col, code, msg =
      line:match('^([^:]+):check%-types:%s+(.-)%((%d+),(%d+)%):%s+error%s+(TS%d+):%s+(.*)$')
    if rel then
      local base = roots[pkg]
      items[#items + 1] = {
        filename = base and (base .. '/' .. rel) or rel,
        lnum = tonumber(lnum),
        col = tonumber(col),
        text = code .. ': ' .. msg,
      }
      last = #items
    elseif last then
      local cont = line:match(':check%-types:%s+(.*)$')
      if cont and cont:match('^%s') then
        items[last].text = items[last].text .. ' ' .. cont:gsub('^%s+', '')
      end
    end
  end

  return items
end

local running = false

function M.run(opts)
  opts = opts or {}

  if running then
    return notify_add('check-types: already running', 'WARN', 'DiagnosticWarn')
  end

  local root = mono_root()
  if not root then
    return notify_add('check-types: no pnpm-workspace.yaml found', 'ERROR', 'DiagnosticError')
  end

  local cmd = { 'pnpm', 'exec', 'turbo', 'run', 'check-types', '--ui=stream' }
  local scope = 'monorepo'
  if opts.filter and opts.filter ~= '' then
    vim.list_extend(cmd, { '--filter', opts.filter })
    scope = opts.filter
  end

  running = true
  local started_at = vim.loop.hrtime()
  local roots = pkg_roots(root)
  local notify_id = notify_add('check-types: running (' .. scope .. ')...', 'INFO', 'DiagnosticInfo')

  vim.system(cmd, { cwd = root, text = true }, vim.schedule_wrap(function(obj)
    running = false
    local elapsed = (vim.loop.hrtime() - started_at) / 1e9
    local elapsed_msg = string.format(' (%.1fs)', elapsed)

    if obj.code == nil then
      return notify_finish(notify_id, 'check-types: cancelled' .. elapsed_msg, 'WARN', 'DiagnosticWarn')
    end

    local output = (obj.stdout or '') .. (obj.stderr or '')
    local lines = vim.split(output, '\n', { plain = true })
    local items = M.parse(lines, roots)

    vim.fn.setqflist({}, ' ', { title = 'check-types', items = items })

    if #items == 0 then
      vim.cmd('cclose')
      local msg = 'check-types: clean' .. elapsed_msg
      if obj.code ~= 0 then
        msg = msg .. ' (turbo exit ' .. obj.code .. ')'
      end
      return notify_finish(notify_id, msg, 'INFO', 'DiagnosticInfo')
    end

    vim.cmd('copen')
    notify_finish(
      notify_id,
      string.format('check-types: %d error%s%s', #items, #items == 1 and '' or 's', elapsed_msg),
      'ERROR',
      'DiagnosticError'
    )
  end))
end

return M
