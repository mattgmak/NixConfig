local M = {}

local bridge = require('plugins.vscode-telescope.bridge')
local log = require('plugins.vscode-telescope.log')
local terminal = require('plugins.vscode-telescope.terminal')
local setup = require('plugins.telescope.setup')

local function pick(picker, extra)
  extra = extra or {}
  log.debug('keymap_pick', { picker = picker, extra = extra })
  local opts = {
    opts = extra.opts or {},
    default_text = extra.default_text,
    file = extra.file,
  }
  bridge.run_picker(picker, opts)
end

local function register_debug_commands()
  vim.api.nvim_create_user_command('TelescopeBridgeLog', function()
    vim.cmd('edit ' .. vim.fn.fnameescape(log.log_path()))
  end, { desc = 'Open vscode-telescope debug log' })

  vim.api.nvim_create_user_command('TelescopeBridgeLogTail', function(opts)
    local n = tonumber(opts.args) or 30
    local lines = log.tail(n)
    if #lines == 0 then
      require('vscode').notify('Telescope log empty: ' .. log.log_path(), vim.log.levels.INFO)
      return
    end
    require('vscode').notify(table.concat(lines, '\n'), vim.log.levels.INFO)
  end, { nargs = '?', desc = 'Show last N debug log lines in notification' })

  vim.api.nvim_create_user_command('TelescopeBridgeLogClear', function()
    log.clear()
    require('vscode').notify('Cleared ' .. log.log_path(), vim.log.levels.INFO)
  end, { desc = 'Clear vscode-telescope debug log' })

  vim.api.nvim_create_user_command('TelescopeBridgeTest', function()
    require('plugins.vscode-telescope.test').run()
  end, { desc = 'Run vscode-telescope self tests' })

  vim.api.nvim_create_user_command('TelescopeBridgePing', function()
    local ok, detail = require('plugins.vscode-telescope.rpc').ping()
    require('vscode').notify(
      'sidecar ping: ' .. tostring(ok) .. ' (' .. tostring(detail) .. ')',
      ok and vim.log.levels.INFO or vim.log.levels.WARN
    )
  end, { desc = 'Ping vscode-telescope sidecar socket' })

  vim.api.nvim_create_user_command('TelescopeBridgeStatus', function()
    local rpc = require('plugins.vscode-telescope.rpc')
    local ok, detail = rpc.ping()
    local status = {
      ping = ok,
      detail = detail,
      socket = terminal.socket_path(),
      socket_exists = rpc.socket_exists(),
      ready_exists = rpc.ready_exists(),
      ready_version = rpc.ready_version(),
      bridge_version = require('plugins.vscode-telescope.paths').BRIDGE_VERSION,
      log = log.log_path(),
    }
    log.info('status_dump', status)
    require('vscode').notify(vim.inspect(status), vim.log.levels.INFO)
  end, { desc = 'Show vscode-telescope bridge status' })

  vim.api.nvim_create_user_command('TelescopeBridgeRestart', function()
    terminal.kill_sidecar()
    require('vscode').notify('Telescope sidecar stopped. Next pick will spawn a fresh one.', vim.log.levels.INFO)
  end, { desc = 'Kill vscode-telescope sidecar process' })
end

function M.setup()
  log.info('setup', {
    debug = log.enabled(),
    strict = log.strict(),
    log_path = log.log_path(),
    socket = terminal.socket_path(),
  })

  register_debug_commands()

  vim.keymap.set({ 'n' }, '<leader>jj', function()
    pick('builtin')
  end, { desc = 'Telescope builtins' })

  vim.keymap.set({ 'n' }, '<leader><leader>', function()
    pick('find_files')
  end, { desc = 'Find files' })

  vim.keymap.set({ 'v' }, '<leader><leader>', function()
    pick('find_files', { default_text = setup.get_selection() })
  end, { desc = 'Find files' })

  vim.keymap.set({ 'n', 'v' }, '<leader>jf', function()
    local file = terminal.get_active_file()
    if not file then
      log.warn('pick_jf_no_file', {})
      require('vscode').notify('No file editor active', vim.log.levels.WARN)
      return
    end
    pick('current_buffer_fuzzy_find', {
      file = file,
      default_text = setup.get_selection(),
    })
  end, { desc = 'Find in active file' })

  vim.keymap.set({ 'n' }, '<leader>jg', function()
    pick('multigrep')
  end, { desc = 'Find within files' })

  vim.keymap.set({ 'v' }, '<leader>jg', function()
    local text = setup.get_selection()
    if text and text ~= '' then
      text = vim.fn.escape(text, [[\/.*$^~[()]])
    end
    pick('multigrep', { default_text = text })
  end, { desc = 'Find within files' })

  vim.keymap.set({ 'n' }, '<leader>jp', function()
    pick('pickers')
  end, { desc = 'Find cached pickers' })

  vim.keymap.set('n', '<leader>jv', function()
    pick('resume')
  end, { desc = 'Resume last Telescope' })

  vim.keymap.set('n', '<leader>jh', function()
    pick('help_tags')
  end, { desc = 'Help tags' })
end

return M
