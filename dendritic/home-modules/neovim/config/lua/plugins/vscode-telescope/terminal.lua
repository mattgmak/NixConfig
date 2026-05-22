local M = {}

local assert_mod = require('plugins.vscode-telescope.assert')
local log = require('plugins.vscode-telescope.log')
local paths = require('plugins.vscode-telescope.paths')
local rpc = require('plugins.vscode-telescope.rpc')
local vscode = require('vscode')

local TERMINAL_NAME = 'Telescope Bridge'
local SHELL = '/bin/bash'

function M.socket_path()
  return paths.socket_path()
end

function M.pending_request_path()
  return paths.pending_request_path()
end

function M.write_pending_request(request_path)
  assert_mod.not_nil(request_path, 'request_path')
  vim.fn.writefile({ request_path }, M.pending_request_path())
  log.info('pending_request_written', {
    request_path = request_path,
    pending_path = M.pending_request_path(),
  })
end

function M.get_workspace_root()
  local root = vscode.eval([[
    const folders = vscode.workspace.workspaceFolders;
    if (!folders || folders.length === 0) return null;
    return folders[0].uri.fsPath;
  ]])
  if root == vim.NIL or root == nil or root == '' then
    root = vim.loop.cwd()
  end
  log.debug('workspace_root', { root = root })
  return root
end

function M.get_active_file()
  local path = vscode.eval([[
    const editor = vscode.window.activeTextEditor;
    if (!editor) return null;
    const uri = editor.document.uri;
    if (uri.scheme !== 'file') return null;
    return uri.fsPath;
  ]])
  if path == vim.NIL or path == nil or path == '' then
    log.debug('active_file_missing', {})
    return nil
  end
  log.debug('active_file', { path = path })
  return path
end

function M.maximize_panel()
  log.debug('panel_maximize', {})
  vscode.call('workbench.action.toggleMaximizedPanel')
end

function M.restore_panel()
  log.debug('panel_restore', {})
  vscode.call('workbench.action.toggleMaximizedPanel')
end

local function spawn_command(root, socket, progpath, ready_path)
  local start_lua = 'lua require("plugins.vscode-telescope.sidecar").start()'
  local inner = string.format(
    'cd %s && rm -f %s %s && exec %s --listen %s -c %s',
    vim.fn.shellescape(root),
    vim.fn.shellescape(socket),
    vim.fn.shellescape(ready_path),
    vim.fn.shellescape(progpath),
    vim.fn.shellescape(socket),
    vim.fn.shellescape(start_lua)
  )
  return '/bin/bash -lc ' .. vim.fn.shellescape(inner)
end

function M.dispatch_pick(request_path)
  assert_mod.file_readable(request_path, 'dispatch request file')
  log.info('dispatch_pick', { request_path = request_path })
  return rpc.dispatch(request_path)
end

function M.kill_sidecar()
  local ready_path = paths.ready_path()
  local pid = rpc.ready_pid()

  if pid and pid > 0 then
    log.info('kill_sidecar', { pid = pid })
    pcall(vim.fn.kill, pid, 15)
    vim.wait(500, function()
      local ok = pcall(vim.fn.kill, pid, 0)
      return not ok
    end, 50)
  end

  pcall(vim.fn.delete, paths.socket_path())
  pcall(vim.fn.delete, ready_path)
  pcall(vim.fn.delete, paths.pending_request_path())
end

function M.spawn_sidecar(on_ready)
  M.kill_sidecar()

  local socket = M.socket_path()
  local ready_path = paths.ready_path()
  local root = M.get_workspace_root()
  local progpath = vim.v.progpath
  local cmd = spawn_command(root, socket, progpath, ready_path)

  log.info('spawn_sidecar', { socket = socket, root = root, progpath = progpath, cmd = cmd })

  vscode.eval(
    [[
      const root = args.root;
      const terminalName = args.terminalName;
      const shellPath = args.shellPath;
      const cmd = args.cmd;

      let term = (globalThis._vscodeTelescopeTerm && globalThis._vscodeTelescopeTerm.exitStatus === undefined)
        ? globalThis._vscodeTelescopeTerm
        : vscode.window.terminals.find((t) => t.name === terminalName);

      if (!term || term.exitStatus !== undefined) {
        term = vscode.window.createTerminal({ name: terminalName, cwd: root, shellPath });
        globalThis._vscodeTelescopeTerm = term;
      }

      term.show(true);
      logger.info('[vscode-telescope] spawn cmd: ' + cmd);
      term.sendText('\u0003', false);
      term.sendText(cmd, true);
      return true;
    ]],
    {
      args = {
        root = root,
        terminalName = TERMINAL_NAME,
        shellPath = SHELL,
        cmd = cmd,
      },
    }
  )

  on_ready()
end



return M
