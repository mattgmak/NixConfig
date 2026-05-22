local M = {}

-- Bump when sidecar protocol/behavior changes so embedded restarts stale processes.
M.BRIDGE_VERSION = 3

function M.socket_path()
  return vim.fn.stdpath('data') .. '/vscode-telescope.sock'
end

function M.pending_request_path()
  return M.socket_path() .. '.pending'
end

function M.ready_path()
  return M.socket_path() .. '.ready'
end

function M.log_path()
  return vim.fn.stdpath('data') .. '/vscode-telescope/debug.log'
end

return M
