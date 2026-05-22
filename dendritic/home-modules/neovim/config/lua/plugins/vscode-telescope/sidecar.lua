local M = {}

local assert_mod = require('plugins.vscode-telescope.assert')
local json = require('plugins.vscode-telescope.json')
local log = require('plugins.vscode-telescope.log')
local paths = require('plugins.vscode-telescope.paths')
local actions = require('telescope.actions')
local action_state = require('telescope.actions.state')
local builtin = require('telescope.builtin')
local finders = require('telescope.finders')
local pickers_mod = require('telescope.pickers')
local telescope_state = require('telescope.state')
local conf = require('telescope.config').values

M.BRIDGE_VERSION = paths.BRIDGE_VERSION

local function write_result_path(result_path, result)
  if not result_path or result_path == '' then
    log.warn('write_result_missing_path', { result = result })
    return false
  end

  if vim.fn.filereadable(result_path) == 1 then
    log.debug('write_result_skip_existing', { result_path = result_path, result = result })
    return true
  end

  json.write_json(result_path, result)
  log.info('write_result', { result_path = result_path, result = result })
  return true
end

local function read_json(path)
  if vim.fn.filereadable(path) ~= 1 then
    log.error('read_json_missing', { path = path })
    return nil
  end
  local decoded = json.read_json(path)
  if not decoded then
    log.error('read_json_decode_failed', { path = path })
  end
  return decoded
end

local function entry_path(entry)
  return entry.path or entry.filename or entry.value
end

local function get_active_prompt_bufnrs()
  local active = {}

  for _, bufnr in ipairs(telescope_state.get_existing_prompt_bufnrs()) do
    if vim.api.nvim_buf_is_valid(bufnr) and vim.bo[bufnr].filetype == 'TelescopePrompt' then
      active[#active + 1] = bufnr
    elseif not vim.api.nvim_buf_is_valid(bufnr) then
      telescope_state.clear_status(bufnr)
    end
  end

  return active
end

function M.close_pickers()
  local closed = 0

  for _, bufnr in ipairs(telescope_state.get_existing_prompt_bufnrs()) do
    if vim.api.nvim_buf_is_valid(bufnr) then
      pcall(actions.close, bufnr)
      closed = closed + 1
    else
      telescope_state.clear_status(bufnr)
    end
  end

  log.info('close_pickers', { closed = closed, remaining = #get_active_prompt_bufnrs() })
  return closed
end

local function make_bridge_action(picker_name, select_kind, result_path)
  return function(prompt_bufnr)
    local entry = action_state.get_selected_entry()
    if not entry then
      log.warn('bridge_select_no_entry', { picker = picker_name, kind = select_kind })
      return
    end

    local result = {
      picker = picker_name,
      action = select_kind == 'horizontal' and 'horizontal' or 'default',
    }

    if picker_name == 'current_buffer_fuzzy_find' then
      result.file = vim.api.nvim_buf_get_name(0)
      result.line = entry.lnum
      result.col = entry.col or 1
    else
      result.path = entry_path(entry)
      result.line = entry.lnum
      result.col = entry.col or 1
    end

    write_result_path(result_path, result)
    actions.close(prompt_bufnr)
  end
end

local function make_cancel_action(result_path)
  return function(prompt_bufnr)
    write_result_path(result_path, { cancelled = true })
    actions.close(prompt_bufnr)
  end
end

local function with_bridge(picker_name, open_fn, opts, result_path)
  local select_default = make_bridge_action(picker_name, 'default', result_path)
  local select_horizontal = make_bridge_action(picker_name, 'horizontal', result_path)
  local cancel = make_cancel_action(result_path)

  opts = vim.tbl_deep_extend('force', opts or {}, {
    attach_mappings = function(_, map)
      actions.select_default:replace(select_default)
      actions.select_horizontal:replace(select_horizontal)
      map('i', '<Esc>', cancel)
      map('n', '<Esc>', cancel)
      map('i', '<C-c>', cancel)
      map('n', '<C-c>', cancel)
      return true
    end,
  })

  log.info('picker_open', { picker = picker_name, result_path = result_path })
  open_fn(opts)
end

local function wait_for_picker_mount(timeout_ms)
  timeout_ms = timeout_ms or 5000
  local start = vim.loop.hrtime()

  while (vim.loop.hrtime() - start) / 1e6 < timeout_ms do
    local active = get_active_prompt_bufnrs()
    if #active > 0 then
      log.info('picker_mounted', { prompts = active })
      return true
    end
    vim.wait(50, function()
      return #get_active_prompt_bufnrs() > 0
    end, 50)
  end

  log.warn('picker_mount_timeout', { prompts = get_active_prompt_bufnrs() })
  return false
end

local function wait_for_picker_result(result_path, timeout_ms)
  timeout_ms = timeout_ms or 120000
  local start = vim.loop.hrtime()
  local had_prompt = false

  while (vim.loop.hrtime() - start) / 1e6 < timeout_ms do
    if vim.fn.filereadable(result_path) == 1 then
      return 'result'
    end

    local prompts = get_active_prompt_bufnrs()
    if #prompts > 0 then
      had_prompt = true
    elseif had_prompt then
      vim.wait(300, function()
        return vim.fn.filereadable(result_path) == 1 or #get_active_prompt_bufnrs() > 0
      end, 50)

      if vim.fn.filereadable(result_path) == 1 then
        return 'result'
      end

      if #get_active_prompt_bufnrs() > 0 then
        had_prompt = true
      else
        return 'closed'
      end
    end

    vim.wait(100, function()
      if vim.fn.filereadable(result_path) == 1 then
        return true
      end
      if #get_active_prompt_bufnrs() > 0 then
        had_prompt = true
      end
      return false
    end, 100)
  end

  return 'timeout'
end

local pickers

pickers = {
  find_files = function(opts, result_path)
    with_bridge('find_files', builtin.find_files, opts, result_path)
  end,
  current_buffer_fuzzy_find = function(opts, file, result_path)
    if file and file ~= '' then
      vim.cmd('silent! edit ' .. vim.fn.fnameescape(file))
    end
    with_bridge('current_buffer_fuzzy_find', builtin.current_buffer_fuzzy_find, opts, result_path)
  end,
  multigrep = function(opts, result_path)
    with_bridge('multigrep', require('plugins.telescope.multigrep').live_multigrep, opts, result_path)
  end,
  pickers = function(opts, result_path)
    with_bridge('pickers', builtin.pickers, opts, result_path)
  end,
  resume = function(opts, result_path)
    with_bridge('resume', builtin.resume, opts, result_path)
  end,
  builtin = function(opts, result_path)
    pickers_mod.new(opts, {
      prompt_title = 'Telescope Bridge',
      finder = finders.new_table {
        results = {
          { name = 'find_files', label = 'Find Files' },
          { name = 'multigrep', label = 'Multi Grep' },
          { name = 'pickers', label = 'Cached Pickers' },
          { name = 'resume', label = 'Resume' },
          { name = 'help_tags', label = 'Help Tags' },
        },
        entry_maker = function(item)
          return {
            value = item.name,
            display = item.label,
            ordinal = item.label,
          }
        end,
      },
      sorter = conf.generic_sorter(opts),
      attach_mappings = function(_, map)
        local function run(prompt_bufnr)
          local entry = action_state.get_selected_entry()
          actions.close(prompt_bufnr)
          local nested = entry and pickers[entry.value]
          if nested then
            nested({}, result_path)
          end
        end
        map('i', '<CR>', run)
        map('n', '<CR>', run)
        return false
      end,
    }):find()
  end,
  help_tags = function(opts, result_path)
    with_bridge('help_tags', builtin.help_tags, opts, result_path)
  end,
}

function M.start()
  vim.g.vscode_telescope_sidecar = true
  vim.g.vscode_telescope_debug = true
  vim.g.vscode_telescope_bridge_version = M.BRIDGE_VERSION
  vim.o.shortmess = vim.o.shortmess .. 'I'
  log.info('sidecar_start', { pid = vim.fn.getpid(), version = M.BRIDGE_VERSION })

  local request = nil
  local pending_path = paths.pending_request_path()
  if vim.fn.filereadable(pending_path) == 1 then
    local lines = vim.fn.readfile(pending_path)
    request = lines[1]
    pcall(vim.fn.delete, pending_path)
    log.info('sidecar_pending_request', { request = request, pending_path = pending_path })
  else
    log.debug('sidecar_no_pending_request', { pending_path = pending_path })
  end

  local function boot()
    require('plugins.telescope.setup').ensure_loaded()
    vim.g.vscode_telescope_ready = true
    require('plugins.vscode-telescope.rpc').write_ready()
    log.info('sidecar_ready', { request = request, version = M.BRIDGE_VERSION })

    if request and request ~= '' then
      vim.defer_fn(function()
        log.info('sidecar_run_pending', { request_path = request })
        M.run_request(request)
      end, 500)
    end
  end

  if vim.v.vim_did_enter == 1 then
    boot()
  else
    vim.api.nvim_create_autocmd('VimEnter', {
      once = true,
      callback = boot,
    })
  end
end

function M.run_request(request_path)
  log.info('run_request_start', { request_path = request_path, version = M.BRIDGE_VERSION })

  M.close_pickers()

  local request = read_json(request_path)
  if not request then
    log.error('run_request_invalid', { request_path = request_path })
    return
  end

  local result_path = request.result_path
  log.info('run_request_loaded', { request = request })

  local picker = pickers[request.picker]
  if not picker then
    write_result_path(result_path, { cancelled = true, error = 'unknown picker: ' .. tostring(request.picker) })
    return
  end

  local ok, err = pcall(function()
    if request.picker == 'current_buffer_fuzzy_find' then
      picker(request.opts or {}, request.file, result_path)
    else
      picker(request.opts or {}, result_path)
    end
  end)

  if not ok then
    log.error('run_request_error', { err = tostring(err) })
    write_result_path(result_path, { cancelled = true, error = tostring(err) })
    return
  end

  if not wait_for_picker_mount(5000) and vim.fn.filereadable(result_path) ~= 1 then
    log.warn('run_request_mount_failed', { result_path = result_path, picker = request.picker })
    write_result_path(result_path, { cancelled = true, error = 'picker failed to open' })
    return
  end

  local status = wait_for_picker_result(result_path)
  log.info('run_request_wait_done', { status = status, result_path = result_path })

  if vim.fn.filereadable(result_path) ~= 1 then
    if status == 'timeout' then
      log.error('run_request_timeout', { result_path = result_path })
      write_result_path(result_path, { cancelled = true, error = 'picker timed out' })
    else
      log.warn('run_request_cancelled', { result_path = result_path, status = status })
      write_result_path(result_path, { cancelled = true })
    end
  else
    log.info('run_request_done', { result_path = result_path })
  end
end

return M
