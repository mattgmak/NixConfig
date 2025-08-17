local is_vscode = vim.g.vscode ~= nil

-- <leader> key
vim.g.mapleader = ' '

-- hot reload this file
vim.keymap.set('n', '<leader>hr', ':so ~/NixConfig/home-manager/terminal/nvim/config/lua/config.lua<cr>')

-- save
vim.keymap.set('n', '<leader>s', '<cmd>w<cr>', {
  silent = true,
})

-- motion keys (helldivers mappings)
vim.keymap.set({ 'n', 'v' }, 'j', 'k')
vim.keymap.set({ 'n', 'v' }, 'k', 'j')
vim.keymap.set({ 'n', 'v' }, 'l', 'h')
vim.keymap.set({ 'n', 'v' }, ';', 'l')

-- repeat previous f, t, F, T movement
vim.keymap.set('n', "'", ';')

-- paste without overwriting
vim.keymap.set('v', 'p', 'P')

-- redo
vim.keymap.set('n', 'U', '<C-r>')

-- clear search highlight
vim.keymap.set('n', '<Esc>', '<CMD>nohlsearch<cr>', {
  silent = true,
})

-- sync system clipboard
vim.opt.clipboard = 'unnamedplus'

-- search ignore case
vim.opt.ignorecase = true
vim.opt.smartcase = true

-- toggle relative line numbering
vim.keymap.set('n', '<leader>ln', ':set relativenumber!<cr>', {
  silent = true,
})

-- void change
vim.keymap.set('n', 'c', '"_c', {
  noremap = true,
})
vim.keymap.set('n', 'C', '"_C', {
  noremap = true,
})
vim.keymap.set('n', 'x', '"_x', {
  noremap = true,
})

-- yank all
vim.keymap.set('n', '<leader>ya', 'ggyG')

-- visual all
vim.keymap.set('n', '<leader>va', 'ggVG')

if is_vscode then
  -- vim.notify = vscode.notify
  -- vscode-multi-cursor
  vim.api.nvim_set_hl(0, 'VSCodeCursor', {
    bg = '#542fa4',
    fg = 'white',
    default = true,
  })

  vim.api.nvim_set_hl(0, 'VSCodeCursorRange', {
    bg = '#542fa4',
    fg = 'white',
    default = true,
  })

  local cursors = require('vscode-multi-cursor')

  vim.keymap.set({ 'n', 'x', 'i' }, '<c-y>', function() cursors.addSelectionToNextFindMatch() end, {
    silent = true,
  })

  vim.keymap.set({ 'n', 'x', 'i' }, '<cs-y>', function() cursors.addSelectionToPreviousFindMatch() end, {
    silent = true,
  })

  vim.keymap.set({ 'n', 'x', 'i' }, '<cs-o>', function() cursors.selectHighlights() end, {
    silent = true,
  })

  vim.keymap.set('n', 'mcm', cursors.cancel, {
    silent = true,
  })
  vim.keymap.set('n', '<c-y>', 'mciw*:nohl<cr>', {
    remap = true,
    silent = true,
  })

  local vscode = require('vscode')

  vim.keymap.set('n', '<leader>cr', function() vscode.call('editor.action.rename') end)
  vim.keymap.set({ 'n', 'v' }, '<leader>cf', function() vscode.call('editor.action.refactor') end)
  vim.keymap.set('n', '<leader>d', function() vscode.call('workbench.action.closeActiveEditor') end)
  vim.keymap.set('n', '<leader>,', function() vscode.call('workbench.action.showAllEditors') end)
  vim.keymap.set('n', '<leader>fs', function() vscode.call('workbench.action.findInFiles') end)
  vim.keymap.set('n', '<c-e>', function() vscode.call('workbench.action.focusActiveEditorGroup') end)
  vim.keymap.set('n', '<leader>ff', function() vscode.call('workbench.files.action.focusFilesExplorer') end)
  vim.keymap.set('n', '<leader>ft', function() vscode.call('workbench.action.terminal.focus') end)
  vim.keymap.set('n', '<leader>fx', function() vscode.call('workbench.view.extensions') end)
  vim.keymap.set('n', '<leader>fp', function() vscode.call('pr:github.focus') end)
  vim.keymap.set('n', '<leader>ro', function() vscode.call('workbench.action.reopenClosedEditor') end)
  vim.keymap.set('n', '<leader><leader>', function() vscode.call('workbench.action.quickOpen') end)
  vim.keymap.set('n', '<leader>rr', function() vscode.call('vscode-neovim.restart') end)
  vim.keymap.set('n', '<leader>sr', function()
    vscode.call('extension.updateCustomCSS')
    vscode.call('workbench.action.reloadWindow')
  end)
  vim.keymap.set('n', 'gr', function() vscode.call('editor.action.goToReferences') end)
  vim.keymap.set('n', '<leader>fc', function() vscode.call('workbench.scm.focus') end)
  vim.keymap.set('n', '<leader>fl', function() vscode.call('gitlens.views.scm.grouped.focus') end)
  vim.keymap.set('n', '<leader>wc', function() vscode.call('editor.action.dirtydiff.next') end)
  vim.keymap.set('n', '<leader>fo', function() vscode.call('diffEditor.switchSide') end)
  vim.keymap.set('n', '<leader>cn', function() vscode.call('notifications.clearAll') end)
  vim.keymap.set('n', '<leader>n', function()
    vscode.call('editor.action.inlineDiffs.nextChange')
    vscode.call('workbench.action.compareEditor.nextChange')
    vscode.call('workbench.action.editor.nextChange')
    vscode.call('editor.action.dirtydiff.next')
  end)
  vim.keymap.set('n', '<leader>b', function()
    vscode.call('editor.action.inlineDiffs.previousChange')
    vscode.call('workbench.action.compareEditor.previousChange')
    vscode.call('workbench.action.editor.previousChange')
    vscode.call('editor.action.dirtydiff.previous')
  end)
  vim.keymap.set('n', 'gt', function() vscode.call('editor.action.goToTypeDefinition') end)
  vim.keymap.set('n', '<leader>gsy', function()
    vscode.action('git.sync', {
      callback = function(error)
        if error then
          vscode.notify('Sync failed: ' .. error)
        else
          vscode.notify('Sync complete')
        end
      end,
    })
  end)
  vim.keymap.set('n', '<leader>gsa', function()
    vscode.action('git.stageAll', {
      callback = function(error)
        if error then
          vscode.notify('Stage failed: ' .. error)
        else
          vscode.notify('Staged all changes')
        end
      end,
    })
  end)
  vim.keymap.set('n', '<leader>gb', function() vscode.action('git.branchFrom') end)
  vim.keymap.set('n', '<leader>gc', function() vscode.action('git.commit') end)
  vim.keymap.set('n', '<leader>gf', function()
    vscode.action('git.fetchPrune', {
      callback = function(error)
        if error then
          vscode.notify('Fetch failed: ' .. error)
        else
          vscode.notify('Fetch complete')
        end
      end,
    })
  end)
  vim.keymap.set('n', '<leader>gg', function() vscode.action('git.checkout') end)
  vim.keymap.set('n', '<leader>gm', function() vscode.action('git.merge') end)
  vim.keymap.set('n', '<leader>gd', function() vscode.action('gitlens.gitCommands.branch.delete') end)
  vim.keymap.set('n', '<leader>pr', function() vscode.action('gitlens.createPullRequestOnRemote') end)
  vim.keymap.set('n', '<leader>pv', function()
    vscode.action('pr.markFileAsViewed')
    vscode.call('pr:github.focus')
  end)
  vim.keymap.set('n', '<leader>pn', function() vscode.action('pr.unmarkFileAsViewed') end)
  vim.keymap.set('n', '<leader>gst', function() vscode.action('gitlens.gitCommands.status') end)
  vim.keymap.set('n', '<leader>gsf', function() vscode.action('git.stage') end)
  vim.keymap.set('n', '<leader>mc', function() vscode.action('merge-conflict.accept.current') end)
  vim.keymap.set('n', '<leader>mi', function() vscode.action('merge-conflict.accept.incoming') end)
  vim.keymap.set('n', '<leader>mb', function() vscode.action('merge-conflict.accept.both') end)
  vim.keymap.set('n', '<leader>mac', function() vscode.action('merge-conflict.accept.all-current') end)
  vim.keymap.set('n', '<leader>mai', function() vscode.action('merge-conflict.accept.all-incoming') end)
  vim.keymap.set('n', '<leader>mab', function() vscode.action('merge-conflict.accept.all-both') end)
  vim.keymap.set('n', '<leader>mn', function() vscode.action('merge-conflict.next') end)
  vim.keymap.set('n', '<leader>mp', function() vscode.action('merge-conflict.previous') end)
  vim.keymap.set('n', '<leader>js', function() vscode.call('workbench.action.gotoSymbol') end)
  vim.keymap.set('n', '<leader>jf', function() vscode.call('workbench.action.quickTextSearch') end)
  vim.keymap.set('n', '<leader>ja', function() vscode.call('workbench.action.showAllSymbols') end)
  vim.keymap.set('n', '<leader>jc', function() vscode.call('breadcrumbs.focusAndSelect') end)
  vim.keymap.set('n', '<leader>a', function() vscode.call('editor.action.quickFix') end)
  vim.keymap.set('n', '<leader>s', function() vscode.call('workbench.action.files.save') end)
  -- vim.keymap.set('n', '<leader>k', function()
  --     vscode.call("snipe-vscode.switchTab")
  -- end)
  vim.keymap.set('n', '<leader>k', function() vscode.call('workbench.action.showAllEditorsByMostRecentlyUsed') end)
  vim.keymap.set('n', '<leader>ca', function() vscode.call('workbench.action.closeAllEditors') end)
  vim.keymap.set('n', '<leader>o', function() vscode.call('workbench.action.files.openFile') end)

  -- use undotree to replace vanilla undo/redo
  -- local undotree = vscode.eval('return vscode.extensions.getExtension("undotree.undo-tree")')
  -- if undotree then
  --   vscode.notify('Using undotree')
  --   vim.keymap.set('n', '<leader>fu', function() vscode.call('workbench.view.extension.undoTreeContainer') end)
  --   vim.keymap.set('n', 'u', function() vscode.call('undotree.undo') end)

  --   vim.keymap.set('n', 'U', function() vscode.call('undotree.redo') end)
  --   vim.api.nvim_create_autocmd('TextChanged', {
  --     callback = function() vscode.call('undotree.saveAndAdvance') end,
  --   })
  -- end
else
  -- exit
  vim.keymap.set('n', '<leader>d', '<cmd>q<cr>')
end

-- flash
vim.api.nvim_set_hl(0, 'FlashLabel', {
  bg = '#A7005C',
  fg = 'white',
})

vim.api.nvim_set_hl(0, 'FlashMatch', {
  bg = '#7c634c',
  fg = 'white',
})

vim.api.nvim_set_hl(0, 'FlashCurrent', {
  bg = '#7c634c',
  fg = 'white',
})
