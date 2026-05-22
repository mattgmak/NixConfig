local M = {}

local assert_mod = require('plugins.vscode-telescope.assert')
local log = require('plugins.vscode-telescope.log')
local vscode = require('vscode')

local function open_file(path, line, col, view_column)
  line = line or 1
  col = col or 1
  view_column = view_column or 'active'

  assert_mod.not_nil(path, 'open_file path')

  log.info('open_file', {
    path = path,
    line = line,
    col = col,
    view_column = view_column,
  })

  vscode.eval(
    [[
      const path = args.path;
      const line = args.line ?? 1;
      const col = args.col ?? 1;
      const viewColumn = args.viewColumn;

      const uri = vscode.Uri.file(path);
      const options = { preview: false, preserveFocus: false };

      if (viewColumn === 'beside') {
        const active = vscode.window.activeTextEditor;
        options.viewColumn = active
          ? (active.viewColumn ?? vscode.ViewColumn.One) + 1
          : vscode.ViewColumn.Beside;
      }

      const doc = await vscode.workspace.openTextDocument(uri);
      const editor = await vscode.window.showTextDocument(doc, options);
      const pos = new vscode.Position(Math.max(0, line - 1), Math.max(0, col - 1));
      editor.selection = new vscode.Selection(pos, pos);
      editor.revealRange(new vscode.Range(pos, pos), vscode.TextEditorRevealType.InCenter);
      return true;
    ]],
    {
      args = {
        path = path,
        line = line,
        col = col,
        viewColumn = view_column,
      },
    }
  )
end

function M.apply(result)
  if not result or result.cancelled then
    log.info('apply_cancelled', { result = result })
    return
  end

  local picker = result.picker
  local action = result.action or 'default'
  local view_column = action == 'horizontal' and 'beside' or 'active'

  log.info('apply_start', { picker = picker, action = action, result = result })

  if picker == 'current_buffer_fuzzy_find' then
    open_file(result.file or result.path, result.line, result.col, view_column)
    return
  end

  if result.path then
    open_file(result.path, result.line, result.col, view_column)
  else
    log.warn('apply_missing_path', { result = result })
  end
end

return M
