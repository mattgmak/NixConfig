[
  {
    "key" = "tab";
    "command" = "editor.emmet.action.expandAbbreviation";
    "when" =
      "config.emmet.triggerExpansionOnTab && editorTextFocus && !editorReadonly && !editorTabMovesFocus";
  }
  {
    "key" = "tab";
    "command" = "jumpToNextSnippetPlaceholder";
    "when" = "editorTextFocus && hasNextTabstop && inSnippetMode";
  }
  {
    "key" = "tab";
    "command" = "editor.action.inlineSuggest.commit";
    "when" =
      "inlineSuggestionHasIndentationLessThanTabSize && inlineSuggestionVisible && !editorHoverFocused && !editorTabMovesFocus && !suggestWidgetVisible";
  }
  {
    "key" = "tab";
    "command" = "workbench.action.terminal.acceptSelectedSuggestion";
    "when" =
      "terminalFocus && terminalHasBeenCreated && terminalIsOpen && terminalSuggestWidgetVisible || terminalFocus && terminalIsOpen && terminalProcessSupported && terminalSuggestWidgetVisible";
  }
  {
    "key" = "alt+a";
    "command" = "editor.debug.action.toggleBreakpoint";
    "when" = "debuggersAvailable && editorTextFocus";
  }
  {
    "key" = "f9";
    "command" = "-editor.debug.action.toggleBreakpoint";
    "when" = "debuggersAvailable && editorTextFocus";
  }
  {
    "key" = "ctrl+n";
    "command" = "-workbench.action.files.newUntitledFile";
  }
  {
    "key" = "shift+alt+=";
    "command" = "editor.action.fontZoomIn";
  }
  {
    "key" = "shift+alt+-";
    "command" = "editor.action.fontZoomOut";
  }
  {
    "key" = "ctrl+\\";
    "command" = "editor.action.inlineSuggest.trigger";
    "when" =
      "config.github.copilot.inlineSuggest.enable && editorTextFocus && !editorHasSelection && !inlineSuggestionsVisible";
  }
  {
    "key" = "alt+\\";
    "command" = "-editor.action.inlineSuggest.trigger";
    "when" =
      "config.github.copilot.inlineSuggest.enable && editorTextFocus && !editorHasSelection && !inlineSuggestionsVisible";
  }
  {
    "key" = "ctrl+alt+\\";
    "command" = "-jupyter.selectCellContents";
    "when" =
      "editorTextFocus && jupyter.hascodecells && !jupyter.webExtension && !notebookEditorFocused";
  }
  {
    "key" = "ctrl+alt+\\";
    "command" = "github.copilot.generate";
    "when" = "editorTextFocus && github.copilot.activated";
  }
  {
    "key" = "ctrl+enter";
    "command" = "-github.copilot.generate";
    "when" = "editorTextFocus && github.copilot.activated";
  }
  {
    "key" = "ctrl+; a";
    "command" = "-jupyter.insertCellAbove";
    "when" =
      "editorTextFocus && jupyter.hascodecells && !jupyter.webExtension && !notebookEditorFocused";
  }
  {
    "key" = "ctrl+enter";
    "command" = "-github.copilot.generate";
    "when" =
      "editorTextFocus && github.copilot.activated && !inInteractiveInput && !interactiveEditorFocused";
  }
  {
    "key" = "ctrl+l";
    "command" = "-notebook.centerActiveCell";
    "when" = "notebookEditorFocused";
  }
  {
    "key" = "ctrl+shift+\\";
    "command" = "-editor.action.jumpToBracket";
    "when" = "editorTextFocus";
  }
  {
    "key" = "ctrl+shift+\\";
    "command" = "-workbench.action.terminal.focusTabs";
    "when" =
      "terminalFocus && terminalHasBeenCreated || terminalFocus && terminalProcessSupported || terminalHasBeenCreated && terminalTabsFocus || terminalProcessSupported && terminalTabsFocus";
  }
  {
    "key" = "ctrl+i";
    "command" = "-emojisense.quickEmoji";
    "when" = "editorTextFocus";
  }
  {
    "key" = "ctrl+shift+alt+e";
    "command" = "-copilot-labs.use-brush-picker";
    "when" = "editorTextFocus";
  }
  {
    "key" = "ctrl+k ctrl+shift+7";
    "command" = "-chatgpt-vscode.adhoc";
    "when" = "editorHasSelection";
  }
  {
    "key" = "ctrl+shift+alt+b";
    "command" = "chatgpt-vscode.view.focus";
  }
  {
    "key" = "ctrl+shift+s";
    "command" = "workbench.action.files.saveWithoutFormatting";
  }
  {
    "key" = "ctrl+k ctrl+shift+s";
    "command" = "-workbench.action.files.saveWithoutFormatting";
  }
  {
    "key" = "ctrl+shift+s";
    "command" = "-workbench.action.files.saveAs";
  }
  {
    "key" = "ctrl+shift+s";
    "command" = "-workbench.action.files.saveLocalFile";
    "when" = "remoteFileDialogVisible";
  }
  {
    "key" = "ctrl+shift+s";
    "command" = "-markdown-preview-enhanced.syncPreview";
    "when" = "editorLangId == 'markdown'";
  }
  {
    "key" = "ctrl+shift+p";
    "command" = "-workbench.action.quickOpenNavigatePreviousInFilePicker";
    "when" = "inFilesPicker && inQuickOpen";
  }
  {
    "key" = "ctrl+shift+n";
    "command" = "-workbench.action.newWindow";
  }
  {
    "key" = "ctrl+shift+s";
    "command" = "-r.runSource";
    "when" = "editorTextFocus && editorLangId == 'r'";
  }
  {
    "key" = "ctrl+\\";
    "command" = "-workbench.action.splitEditor";
  }
  {
    "key" = "ctrl+shift+i";
    "command" = "-emojisense.quickEmojitext";
    "when" = "editorTextFocus";
  }
  {
    "key" = "ctrl+shift+i";
    "command" = "emojisense.quickEmoji";
  }
  {
    "key" = "ctrl+shift+i";
    "command" = "-workbench.action.toggleDevTools";
    "when" = "isDevelopment";
  }
  {
    "key" = "ctrl+shift+i";
    "command" = "-workbench.action.quickchat.toggle";
    "when" = "hasChatProvider";
  }
  {
    "key" = "ctrl+shift+backspace";
    "command" = "workbench.action.navigateEditorGroups";
  }
  {
    "key" = "ctrl+alt+b";
    "command" = "-r.runFromBeginningToLine";
    "when" = "editorTextFocus && editorLangId == 'r'";
  }
  {
    "key" = "ctrl+alt+b";
    "command" = "-workbench.action.toggleAuxiliaryBar";
  }
  {
    "key" = "ctrl+w";
    "command" = "workbench.action.toggleAuxiliaryBar";
  }
  {
    "key" = "ctrl+enter";
    "command" = "-r.executeInTerminal";
    "when" = "editorFocus && editorLangId == 'r'";
  }
  {
    "key" = "ctrl+shift+enter";
    "command" = "-r.runSourcewithEcho";
    "when" = "editorTextFocus && editorLangId == 'r'";
  }
  {
    "key" = "ctrl+shift+enter";
    "command" = "-r.runCurrentChunk";
    "when" = "editorTextFocus && editorLangId == 'rmd'";
  }
  {
    "key" = "ctrl+shift+enter";
    "command" = "-r.execute";
    "when" = "editorFocus && editorLangId == 'r'";
  }
  {
    "key" = "ctrl+shift+k";
    "command" = "workbench.action.terminal.clear";
    "when" = "terminalFocus";
  }
  {
    "key" = "ctrl+shift+q";
    "command" = "-tabnine.chat.focus-input";
  }
  {
    "key" = "ctrl+k e";
    "command" = "-workbench.files.action.focusOpenEditorsView";
    "when" = "workbench.explorer.openEditorsView.active";
  }
  {
    "key" = "ctrl+alt+f";
    "command" = "references-view.findReferences";
    "when" = "editorHasReferenceProvider";
  }
  {
    "key" = "shift+alt+f12";
    "command" = "-references-view.findReferences";
    "when" = "editorHasReferenceProvider";
  }
  {
    "key" = "alt+f";
    "command" = "editor.action.revealDefinition";
    "when" =
      "editorHasDefinitionProvider && editorTextFocus && !isInEmbeddedEditor";
  }
  {
    "key" = "f12";
    "command" = "-editor.action.revealDefinition";
    "when" =
      "editorHasDefinitionProvider && editorTextFocus && !isInEmbeddedEditor";
  }
  {
    "key" = "alt+c";
    "command" = "-cody.menu.commands";
    "when" = "cody.activated";
  }
  {
    "key" = "ctrl+shift+j";
    "command" = "-workbench.action.search.toggleQueryDetails";
    "when" = "inSearchEditor || searchViewletFocus";
  }
  {
    "key" = "ctrl+`";
    "command" = "-workbench.action.terminal.toggleTerminal";
    "when" = "terminal.active";
  }
  {
    "key" = "ctrl+shift+u";
    "command" = "-workbench.action.output.toggleOutput";
    "when" = "workbench.panel.output.active";
  }
  {
    "key" = "ctrl+,";
    "command" = "editor.action.marker.nextInFiles";
    "when" = "editorFocus";
  }
  {
    "key" = "f8";
    "command" = "-editor.action.marker.nextInFiles";
    "when" = "editorFocus";
  }
  {
    "key" = "ctrl+shift+m";
    "command" = "workbench.actions.view.problems";
    "when" = "workbench.panel.markers.view.active";
  }
  {
    "key" = "ctrl+shift+m";
    "command" = "-workbench.actions.view.problems";
    "when" = "workbench.panel.markers.view.active";
  }
  {
    "key" = "ctrl+shift+";
    "command" = "-editor.action.inPlaceReplace.up";
    "when" = "editorTextFocus && !editorReadonly";
  }
  {
    "key" = "ctrl+,";
    "command" = "-workbench.action.openSettings";
  }
  {
    "key" = "ctrl+shift+";
    "command" = "editor.action.marker.prevInFiles";
    "when" = "editorFocus";
  }
  {
    "key" = "shift+f8";
    "command" = "-editor.action.marker.prevInFiles";
    "when" = "editorFocus";
  }
  {
    "key" = "tab";
    "command" = "-tab";
    "when" = "editorTextFocus && !editorReadonly && !editorTabMovesFocus";
  }
  {
    "key" = "ctrl+m";
    "command" = "-editor.action.toggleTabFocusMode";
  }
  {
    "key" = "ctrl+l ctrl+m";
    "command" = "-editor.action.toggleTabFocusMode";
  }
  {
    "key" = "shift+tab";
    "command" = "outdent";
    "when" = "editorTextFocus && !editorReadonly && !editorTabMovesFocus";
  }
  {
    "key" = "shift+tab";
    "command" = "-outdent";
    "when" = "editorTextFocus && !editorReadonly && !editorTabMovesFocus";
  }
  {
    "key" = "ctrl+shift+alt+a";
    "command" = "editor.action.toggleTabFocusMode";
  }
  {
    "key" = "ctrl+shift+\\";
    "command" = "workbench.action.splitEditorRight";
  }
  {
    "key" = "ctrl+k ctrl+\\";
    "command" = "-workbench.action.splitEditorRight";
  }
  {
    "key" = "ctrl+shift+enter";
    "command" = "-notebook.cell.insertCodeCellAbove";
    "when" = "notebookCellListFocused && !inputFocus";
  }
  {
    "key" = "shift+alt+f";
    "command" = "editor.action.goToTypeDefinition";
  }
  {
    "key" = "ctrl+c";
    "command" = "-gitlens.views.branches.copy";
  }
  {
    "key" = "ctrl+c";
    "command" = "-gitlens.views.commits.copy";
  }
  {
    "key" = "ctrl+c";
    "command" = "-gitlens.views.contributors.copy";
  }
  {
    "key" = "ctrl+c";
    "command" = "-gitlens.views.drafts.copy";
  }
  {
    "key" = "ctrl+c";
    "command" = "-gitlens.views.fileHistory.copy";
  }
  {
    "key" = "ctrl+c";
    "command" = "-gitlens.views.lineHistory.copy";
  }
  {
    "key" = "ctrl+c";
    "command" = "-gitlens.views.pullRequest.copy";
  }
  {
    "key" = "ctrl+c";
    "command" = "-gitlens.views.remotes.copy";
  }
  {
    "key" = "ctrl+c";
    "command" = "-gitlens.views.repositories.copy";
  }
  {
    "key" = "ctrl+c";
    "command" = "-gitlens.views.searchAndCompare.copy";
  }
  {
    "key" = "ctrl+c";
    "command" = "-gitlens.views.stashes.copy";
  }
  {
    "key" = "ctrl+c";
    "command" = "-gitlens.views.tags.copy";
  }
  {
    "key" = "ctrl+c";
    "command" = "-gitlens.views.workspaces.copy";
  }
  {
    "key" = "ctrl+c";
    "command" = "-gitlens.views.worktrees.copy";
  }
  {
    "key" = "alt+j";
    "command" = "-supermaven.newConversationTab";
  }
  {
    "key" = "ctrl+shift+enter";
    "command" = "-markdown-preview-enhanced.runAllCodeChunks";
    "when" = "editorLangId == 'markdown'";
  }
  {
    "key" = "ctrl+alt+n";
    "command" = "-code-runner.run";
  }
  {
    "key" = "ctrl+alt+n";
    "command" = "python.execInTerminal-icon";
  }
  {
    "key" = "ctrl+shift+c";
    "command" = "-workbench.action.terminal.openNativeConsole";
    "when" = "!terminalFocus";
  }
  {
    "key" = "ctrl+shift+`";
    "command" = "-workbench.action.terminal.new";
    "when" =
      "terminalProcessSupported || terminalWebExtensionContributedProfile";
  }
  {
    "key" = "ctrl+alt+j";
    "command" = "-liveshare.join";
    "when" = "liveshare:state != 'Joined' && liveshare:state != 'Shared'";
  }
  {
    "key" = "ctrl+alt+j";
    "command" = "-code-runner.runByLanguage";
  }
  {
    "key" = "ctrl+alt+j";
    "command" = "-latex-workshop.synctex";
  }
  {
    "key" = "ctrl+enter";
    "command" = "-github.copilot.generate";
    "when" =
      "editorTextFocus && github.copilot.activated && !commentEditorFocused && !inInteractiveInput && !interactiveEditorFocused";
  }
  {
    "key" = "alt+a";
    "command" = "editor.emmet.action.wrapWithAbbreviation";
  }
  {
    "key" = "alt+s";
    "command" = "editor.emmet.action.balanceIn";
  }
  {
    "key" = "alt+d";
    "command" = "editor.emmet.action.balanceOut";
  }
  {
    "key" = "ctrl+shift+i";
    "command" = "-supermaven.addToChat";
  }
  {
    "key" = "ctrl+i";
    "command" = "-supermaven.maven";
  }
  {
    "key" = "k";
    "command" = "list.focusDown";
    "when" = "listFocus";
  }
  {
    "key" = "j";
    "command" = "list.focusUp";
    "when" = "listFocus && !inputFocus";
  }
  {
    "key" = "ctrl+shift+r";
    "command" = "-editor.action.refactor";
    "when" =
      "editorHasCodeActionsProvider && textInputFocus && !editorReadonly";
  }
  {
    "key" = "ctrl+shift+r";
    "command" = "workbench.view.scm";
    "when" = "workbench.scm.active";
  }
  {
    "key" = "ctrl+shift+g";
    "command" = "-workbench.view.scm";
    "when" = "workbench.scm.active";
  }
  {
    "key" = "ctrl+shift+w";
    "command" = "-workbench.action.closeWindow";
  }
  {
    "key" = "ctrl+w";
    "command" = "-workbench.action.closeActiveEditor";
  }
  {
    "key" = "f2";
    "command" = "-workbench.action.terminal.renameActiveTab";
    "when" =
      "terminalHasBeenCreated && terminalTabsFocus && terminalTabsSingularSelection || terminalProcessSupported && terminalTabsFocus && terminalTabsSingularSelection";
  }
  {
    "key" = "ctrl+\\";
    "command" = "hideSuggestWidget";
    "when" = "suggestWidgetVisible && textInputFocus";
  }
  {
    "key" = "shift+escape";
    "command" = "-hideSuggestWidget";
    "when" = "suggestWidgetVisible && textInputFocus";
  }
  {
    "key" = "ctrl+u";
    "command" = "-vscode-neovim.ctrl-u";
    "when" =
      "editorTextFocus && neovim.ctrlKeysNormal.u && neovim.init && neovim.mode != 'insert' && editorLangId not in 'neovim.editorLangIdExclusions'";
  }
  {
    "key" = "ctrl+d";
    "command" = "-vscode-neovim.ctrl-d";
    "when" =
      "editorTextFocus && neovim.ctrlKeysNormal.d && neovim.init && neovim.mode != 'insert' && editorLangId not in 'neovim.editorLangIdExclusions'";
  }
  {
    "key" = "ctrl+u";
    "command" = "runCommands";
    "args" = {
      "commands" = [
        {
          "command" = "vscode-neovim.send";
          "args" = "<C-u>";
        }
        {
          "command" = "editorScroll";
          "args" = {
            "to" = "up";
            "by" = "halfPage";
          };
        }
      ];
    };
    "when" = "editorTextFocus";
  }
  {
    "key" = "ctrl+d";
    "command" = "runCommands";
    "args" = {
      "commands" = [
        {
          "command" = "vscode-neovim.send";
          "args" = "<C-d>";
        }
        {
          "command" = "editorScroll";
          "args" = {
            "to" = "down";
            "by" = "halfPage";
          };
        }
      ];
    };
    "when" = "editorTextFocus";
  }
  {
    "key" = "ctrl+shift+u";
    "command" = "runCommands";
    "args" = {
      "commands" = [
        {
          "command" = "vscode-neovim.send";
          "args" = "<CS-u>";
        }
        {
          "command" = "editorScroll";
          "args" = {
            "to" = "up";
            "by" = "page";
          };
        }
      ];
    };
    "when" = "editorTextFocus";
  }
  {
    "key" = "ctrl+shift+d";
    "command" = "runCommands";
    "args" = {
      "commands" = [
        {
          "command" = "vscode-neovim.send";
          "args" = "<CS-d>";
        }
        {
          "command" = "editorScroll";
          "args" = {
            "to" = "down";
            "by" = "page";
          };
        }
      ];
    };
    "when" = "editorTextFocus";
  }
  {
    "key" = "ctrl+w -";
    "command" = "-workbench.action.decreaseViewHeight";
    "when" =
      "!editorTextFocus && !isAuxiliaryWindowFocusedContext && !terminalFocus && neovim.mode != 'cmdline'";
  }
  {
    "key" = "ctrl+w unknown";
    "command" = "-workbench.action.decreaseViewWidth";
    "when" =
      "!editorTextFocus && !isAuxiliaryWindowFocusedContext && !terminalFocus && neovim.mode != 'cmdline'";
  }
  {
    "key" = "ctrl+w unknown";
    "command" = "-workbench.action.increaseViewHeight";
    "when" =
      "!editorTextFocus && !isAuxiliaryWindowFocusedContext && !terminalFocus && neovim.mode != 'cmdline'";
  }
  {
    "key" = "ctrl+w unknown";
    "command" = "-workbench.action.increaseViewWidth";
    "when" =
      "!editorTextFocus && !isAuxiliaryWindowFocusedContext && !terminalFocus && neovim.mode != 'cmdline'";
  }
  {
    "key" = "ctrl+w ctrl+w";
    "command" = "-workbench.action.focusNextGroup";
    "when" =
      "!editorTextFocus && !filesExplorerFocus && !inSearchEditor && !replaceInputBoxFocus && !searchViewletFocus && !terminalFocus && neovim.mode != 'cmdline'";
  }
  {
    "key" = "ctrl+w up";
    "command" = "-workbench.action.navigateUp";
    "when" = "!editorTextFocus && !terminalFocus && neovim.mode != 'cmdline'";
  }
  {
    "key" = "ctrl+w k";
    "command" = "-workbench.action.navigateUp";
    "when" = "!editorTextFocus && !terminalFocus && neovim.mode != 'cmdline'";
  }
  {
    "key" = "ctrl+w down";
    "command" = "-workbench.action.navigateDown";
    "when" = "!editorTextFocus && !terminalFocus && neovim.mode != 'cmdline'";
  }
  {
    "key" = "ctrl+w j";
    "command" = "-workbench.action.navigateDown";
    "when" = "!editorTextFocus && !terminalFocus && neovim.mode != 'cmdline'";
  }
  {
    "key" = "ctrl+w left";
    "command" = "-workbench.action.navigateLeft";
    "when" = "!editorTextFocus && !terminalFocus && neovim.mode != 'cmdline'";
  }
  {
    "key" = "ctrl+w h";
    "command" = "-workbench.action.navigateLeft";
    "when" = "!editorTextFocus && !terminalFocus && neovim.mode != 'cmdline'";
  }
  {
    "key" = "ctrl+w right";
    "command" = "-workbench.action.navigateRight";
    "when" = "!editorTextFocus && !terminalFocus && neovim.mode != 'cmdline'";
  }
  {
    "key" = "ctrl+w l";
    "command" = "-workbench.action.navigateRight";
    "when" = "!editorTextFocus && !terminalFocus && neovim.mode != 'cmdline'";
  }
  {
    "key" = "ctrl+w =";
    "command" = "-workbench.action.evenEditorWidths";
    "when" = "!editorTextFocus && !terminalFocus && neovim.mode != 'cmdline'";
  }
  {
    "key" = "ctrl+w s";
    "command" = "-workbench.action.splitEditorDown";
    "when" = "!editorTextFocus && !terminalFocus && neovim.mode != 'cmdline'";
  }
  {
    "key" = "ctrl+w v";
    "command" = "-workbench.action.splitEditorRight";
    "when" = "!editorTextFocus && !terminalFocus && neovim.mode != 'cmdline'";
  }
  {
    "key" = "ctrl+w unknown";
    "command" = "-workbench.action.toggleEditorWidths";
    "when" = "!editorTextFocus && !terminalFocus && neovim.mode != 'cmdline'";
  }
  {
    "key" = "ctrl+w";
    "command" = "vscode-neovim.send-cmdline";
    "when" = "neovim.init && neovim.mode == 'cmdline'";
  }
  {
    "key" = "ctrl+w";
    "command" = "vscode-neovim.send";
    "when" =
      "editorTextFocus && neovim.ctrlKeysInsert.w && neovim.init && neovim.mode == 'insert' && editorLangId not in 'neovim.editorLangIdExclusions'";
  }
  {
    "key" = "ctrl+w";
    "command" = "workbench.action.terminal.killEditor";
    "when" =
      "terminalEditorFocus && terminalFocus && terminalHasBeenCreated || terminalEditorFocus && terminalFocus && terminalProcessSupported";
  }
  {
    "key" = "ctrl+f4";
    "command" = "-workbench.action.terminal.killEditor";
    "when" =
      "terminalEditorFocus && terminalFocus && terminalHasBeenCreated || terminalEditorFocus && terminalFocus && terminalProcessSupported";
  }
  {
    "key" = "f2";
    "command" = "-renameFile";
    "when" =
      "filesExplorerFocus && foldersViewVisible && !explorerResourceIsRoot && !explorerResourceReadonly && !inputFocus";
  }
  {
    "key" = "f2";
    "command" = "-remote.tunnel.label";
    "when" =
      "tunnelViewFocus && tunnelType == 'Forwarded' && tunnelViewMultiSelection == 'undefined'";
  }
  {
    "key" = "f2";
    "command" = "-debug.setVariable";
    "when" = "variablesFocused";
  }
  {
    "key" = "ctrl+c";
    "command" = "-vscode-neovim.escape";
    "when" =
      "editorTextFocus && neovim.ctrlKeysNormal.c && neovim.init && !dirtyDiffVisible && !findWidgetVisible && !inReferenceSearchEditor && !markersNavigationVisible && !notebookCellFocused && !notificationCenterVisible && !parameterHintsVisible && !referenceSearchVisible && neovim.mode == 'normal' && editorLangId not in 'neovim.editorLangIdExclusions'";
  }
  {
    "key" = "ctrl+c";
    "command" = "-vscode-neovim.escape";
    "when" =
      "editorTextFocus && neovim.ctrlKeysInsert.c && neovim.init && neovim.mode != 'normal' && editorLangId not in 'neovim.editorLangIdExclusions'";
  }
  {
    "key" = "ctrl+p";
    "command" = "-workbench.action.quickOpenSelectPrevious";
    "when" = "inQuickOpen && neovim.mode != 'cmdline'";
  }
  {
    "key" = "ctrl+n";
    "command" = "-workbench.action.quickOpenSelectNext";
    "when" = "inQuickOpen && neovim.mode != 'cmdline'";
  }
  {
    "key" = "ctrl+e";
    "command" = "-workbench.action.quickOpen";
  }
  {
    "key" = "ctrl+shift+f";
    "command" = "rerunSearchEditorSearch";
    "when" = "inSearchEditor";
  }
  {
    "key" = "ctrl+shift+r";
    "command" = "-rerunSearchEditorSearch";
    "when" = "inSearchEditor";
  }
  {
    "key" = "f4";
    "command" = "-search.action.focusNextSearchResult";
    "when" = "hasSearchResult || inSearchEditor";
  }
  {
    "key" = "shift+f4";
    "command" = "-search.action.focusPreviousSearchResult";
    "when" = "hasSearchResult || inSearchEditor";
  }
  {
    "key" = "tab";
    "command" = "search.action.focusSearchList";
    "when" = "searchInputBoxFocus";
  }
  {
    "key" = "ctrl+i";
    "command" = "-workbench.action.terminal.chat.focusInput";
    "when" = "terminalChatFocus && !inlineChatFocused";
  }
  {
    "key" = "ctrl+i";
    "command" = "-inlineChat.start";
    "when" = "editorFocus && inlineChatHasProvider && !editorReadonly";
  }
  {
    "key" = "ctrl+i";
    "command" = "-workbench.action.terminal.chat.start";
    "when" =
      "inlineChatHasProvider && terminalFocusInAny && terminalHasBeenCreated || inlineChatHasProvider && terminalFocusInAny && terminalProcessSupported";
  }
  {
    "key" = "ctrl+i";
    "command" = "-workbench.action.chat.startVoiceChat";
    "when" =
      "chatIsEnabled && hasSpeechProvider && inChatInput && !chatSessionRequestInProgress && !editorFocus && !notebookEditorFocused && !scopedVoiceChatGettingReady && !speechToTextInProgress && !terminalChatActiveRequest || chatIsEnabled && hasSpeechProvider && inlineChatFocused && !chatSessionRequestInProgress && !editorFocus && !notebookEditorFocused && !scopedVoiceChatGettingReady && !speechToTextInProgress && !terminalChatActiveRequest";
  }
  {
    "key" = "ctrl+i";
    "command" = "-workbench.action.chat.stopListeningAndSubmit";
    "when" =
      "inChatInput && voiceChatInProgress && scopedVoiceChatInProgress == 'editor' || inChatInput && voiceChatInProgress && scopedVoiceChatInProgress == 'inline' || inChatInput && voiceChatInProgress && scopedVoiceChatInProgress == 'quick' || inChatInput && voiceChatInProgress && scopedVoiceChatInProgress == 'terminal' || inChatInput && voiceChatInProgress && scopedVoiceChatInProgress == 'view' || inlineChatFocused && voiceChatInProgress && scopedVoiceChatInProgress == 'editor' || inlineChatFocused && voiceChatInProgress && scopedVoiceChatInProgress == 'inline' || inlineChatFocused && voiceChatInProgress && scopedVoiceChatInProgress == 'quick' || inlineChatFocused && voiceChatInProgress && scopedVoiceChatInProgress == 'terminal' || inlineChatFocused && voiceChatInProgress && scopedVoiceChatInProgress == 'view'";
  }
  {
    "key" = "ctrl+i";
    "command" = "-supermaven.editWithSupermaven";
  }
  {
    "key" = "ctrl+i";
    "command" = "-editor.action.triggerSuggest";
    "when" =
      "editorHasCompletionItemProvider && textInputFocus && !editorReadonly && !suggestWidgetVisible";
  }
  {
    "key" = "ctrl+alt+up";
    "command" = "workbench.action.navigateUp";
  }
  {
    "key" = "ctrl+alt+down";
    "command" = "workbench.action.navigateDown";
  }
  {
    "key" = "ctrl+u";
    "command" = "workbench.action.terminal.scrollUpPage";
    "when" =
      "terminalFocusInAny && terminalHasBeenCreated && !terminalAltBufferActive || terminalFocusInAny && terminalProcessSupported && !terminalAltBufferActive";
  }
  {
    "key" = "shift+pageup";
    "command" = "-workbench.action.terminal.scrollUpPage";
    "when" =
      "terminalFocusInAny && terminalHasBeenCreated && !terminalAltBufferActive || terminalFocusInAny && terminalProcessSupported && !terminalAltBufferActive";
  }
  {
    "key" = "ctrl+d";
    "command" = "workbench.action.terminal.scrollDownPage";
    "when" =
      "terminalFocusInAny && terminalHasBeenCreated && !terminalAltBufferActive || terminalFocusInAny && terminalProcessSupported && !terminalAltBufferActive";
  }
  {
    "key" = "shift+pagedown";
    "command" = "-workbench.action.terminal.scrollDownPage";
    "when" =
      "terminalFocusInAny && terminalHasBeenCreated && !terminalAltBufferActive || terminalFocusInAny && terminalProcessSupported && !terminalAltBufferActive";
  }
  {
    "key" = "ctrl+r";
    "command" = "-workbench.action.openRecent";
  }
  {
    "key" = "down";
    "command" = "-vscode-neovim.send";
    "when" =
      "neovim.init && neovim.recording || editorTextFocus && neovim.init && neovim.mode != 'insert' && editorLangId not in 'neovim.editorLangIdExclusions'";
  }
  {
    "key" = "up";
    "command" = "-vscode-neovim.send";
    "when" =
      "neovim.init && neovim.recording || editorTextFocus && neovim.init && neovim.mode != 'insert' && editorLangId not in 'neovim.editorLangIdExclusions'";
  }
  {
    "key" = "left";
    "command" = "-vscode-neovim.send";
    "when" =
      "neovim.init && neovim.recording || editorTextFocus && neovim.init && neovim.mode != 'insert' && editorLangId not in 'neovim.editorLangIdExclusions'";
  }
  {
    "key" = "right";
    "command" = "-vscode-neovim.send";
    "when" =
      "neovim.init && neovim.recording || editorTextFocus && neovim.init && neovim.mode != 'insert' && editorLangId not in 'neovim.editorLangIdExclusions'";
  }
  {
    "key" = "ctrl+p";
    "command" = "-list.focusUp";
    "when" = "inReferenceSearchEditor && neovim.mode == 'normal'";
  }
  {
    "key" = "ctrl+p";
    "command" = "-list.focusUp";
    "when" = "listFocus && !inputFocus";
  }
  {
    "key" = "ctrl+d";
    "command" = "-list.focusPageDown";
    "when" = "listFocus && !inputFocus";
  }
  {
    "args" = "<cs-o>";
    "command" = "vscode-neovim.send";
    "key" = "ctrl+shift+o";
    "when" = "editorFocus && neovim.init && neovim.mode == 'normal'";
  }
  {
    "key" = "z c";
    "command" = "-list.collapse";
    "when" = "!editorTextFocus && !inputFocus";
  }
  {
    "key" = "z f";
    "command" = "list.collapseAllToFocus";
    "when" = "!editorTextFocus && !inputFocus";
  }
  {
    "key" = "z shift+c";
    "command" = "-list.collapseAllToFocus";
    "when" = "!editorTextFocus && !inputFocus";
  }
  {
    "key" = "ctrl+j";
    "command" = "-vscode-neovim.send";
    "when" =
      "editorTextFocus && neovim.ctrlKeysInsert.j && neovim.init && neovim.mode == 'insert' && editorLangId not in 'neovim.editorLangIdExclusions'";
  }
  {
    "key" = "ctrl+j";
    "command" = "-vscode-neovim.send";
    "when" =
      "editorTextFocus && neovim.ctrlKeysNormal.j && neovim.init && neovim.mode != 'insert' && editorLangId not in 'neovim.editorLangIdExclusions'";
  }
  {
    "key" = "ctrl+u";
    "command" = "-vscode-neovim.send";
    "when" =
      "editorTextFocus && neovim.ctrlKeysInsert.u && neovim.init && neovim.mode == 'insert' && editorLangId not in 'neovim.editorLangIdExclusions'";
  }
  {
    "key" = "ctrl+d";
    "command" = "editor.action.pageDownHover";
    "when" = "editorHoverFocused";
  }
  {
    "key" = "ctrl+d";
    "command" = "-editor.action.pageDownHover";
    "when" = "editorHoverFocused";
  }
  {
    "key" = "ctrl+u";
    "command" = "-cursorUndo";
    "when" = "textInputFocus";
  }
  {
    "key" = "ctrl+d";
    "command" = "-editor.action.addSelectionToNextFindMatch";
    "when" = "editorFocus";
  }
  {
    "args" = "<c-y>";
    "command" = "vscode-neovim.send";
    "key" = "ctrl+y";
    "when" = "editorFocus && neovim.init";
  }
  {
    "key" = "ctrl+d";
    "command" = "-vscode-neovim.send";
    "when" =
      "editorTextFocus && neovim.ctrlKeysInsert.d && neovim.init && neovim.mode == 'insert' && editorLangId not in 'neovim.editorLangIdExclusions'";
  }
  {
    "key" = "ctrl+d";
    "command" = "-notebook.addFindMatchToSelection";
    "when" =
      "config.notebook.multiSelect.enabled && notebookCellEditorFocused && activeEditor == 'workbench.editor.notebook'";
  }
  {
    "key" = "ctrl+y";
    "command" = "-vscode-neovim.ctrl-y";
    "when" =
      "editorTextFocus && neovim.ctrlKeysNormal.y && neovim.init && neovim.mode != 'insert' && editorLangId not in 'neovim.editorLangIdExclusions'";
  }
  {
    "key" = "ctrl+y";
    "command" = "-redo";
  }
  {
    "key" = "ctrl+shift+n";
    "command" = "workbench.action.newWindow";
  }
  {
    "key" = "ctrl+m k";
    "command" = "composer.startComposerPrompt";
    "when" = "composerIsEnabled";
  }
  {
    "key" = "ctrl+i";
    "command" = "-composer.startComposerPrompt";
    "when" = "composerIsEnabled";
  }
  {
    "key" = "ctrl+shift+h";
    "command" = "-workbench.action.replaceInFiles";
  }
  {
    "key" = "ctrl+shift+h";
    "command" = "controlPanel.openControlPanel";
  }
  {
    "key" = "ctrl+shift+i";
    "command" = "-controlPanel.openControlPanel";
  }
  {
    "key" = "ctrl+shift+y";
    "command" = "editor.action.addSelectionToPreviousFindMatch";
  }
  {
    "key" = "ctrl+escape";
    "command" = "workbench.action.focusActiveEditorGroup";
    "when" = "terminalFocus || sideBarFocus";
  }
  {
    "key" = "ctrl+escape";
    "command" = "-workbench.action.focusActiveEditorGroup";
    "when" = "terminalFocus";
  }
  {
    "key" = "ctrl+m ctrl+p";
    "command" = "-workbench.action.showAllEditors";
  }
  {
    "key" = "ctrl+m p";
    "command" = "-workbench.action.files.copyPathOfActiveFile";
  }
  {
    "key" = "ctrl+m ctrl+g";
    "command" = "-aiFeedback.action.open";
  }
  {
    "key" = "k";
    "command" = "selectNextCodeAction";
    "when" = "codeActionMenuVisible";
  }
  {
    "key" = "ctrl+n";
    "command" = "-selectNextCodeAction";
    "when" = "codeActionMenuVisible";
  }
  {
    "key" = "j";
    "command" = "selectPrevCodeAction";
    "when" = "codeActionMenuVisible";
  }
  {
    "key" = "ctrl+p";
    "command" = "-selectPrevCodeAction";
    "when" = "codeActionMenuVisible";
  }
  {
    "key" = "ctrl+up";
    "command" = "-selectPrevCodeAction";
    "when" = "codeActionMenuVisible";
  }
  {
    "key" = "ctrl+down";
    "command" = "-selectNextCodeAction";
    "when" = "codeActionMenuVisible";
  }
  {
    "key" = "k";
    "command" = "editor.action.scrollDownHover";
    "when" = "editorHoverFocused";
  }
  {
    "key" = "j";
    "command" = "-editor.action.scrollDownHover";
    "when" = "editorHoverFocused";
  }
  {
    "key" = "j";
    "command" = "editor.action.scrollUpHover";
    "when" = "editorHoverFocused";
  }
  {
    "key" = "k";
    "command" = "-editor.action.scrollUpHover";
    "when" = "editorHoverFocused";
  }
  {
    "key" = "k";
    "command" = "-list.focusUp";
    "when" = "listFocus && !inputFocus";
  }
  {
    "key" = "j";
    "command" = "list.focusUp";
    "when" =
      "notebookEditorFocused && !inputFocus && !notebookOutputInputFocused";
  }
  {
    "key" = "k";
    "command" = "-list.focusUp";
    "when" =
      "notebookEditorFocused && !inputFocus && !notebookOutputInputFocused";
  }
  {
    "key" = "j";
    "command" = "-list.focusDown";
    "when" = "listFocus && !inputFocus";
  }
  {
    "key" = "j";
    "command" = "-list.focusDown";
    "when" =
      "notebookEditorFocused && !inputFocus && !notebookOutputInputFocused";
  }
  {
    "key" = "j";
    "command" = "vscode-neovim.send";
    "when" =
      "editorTextFocus && neovim.init && focusedView == 'workbench.panel.output' && neovim.mode != 'insert'";
  }
  {
    "key" = "j";
    "command" = "-vscode-neovim.send";
    "when" =
      "editorTextFocus && neovim.init && focusedView == 'workbench.panel.output' && neovim.mode != 'insert'";
  }
  {
    "key" = "ctrl+s";
    "command" = "workbench.action.focusSideBar";
    "when" = "!sideBarVisible";
  }
  {
    "key" = "ctrl+s";
    "command" = "workbench.action.toggleSidebarVisibility";
    "when" = "sideBarVisible || sideBarFocus";
  }
  {
    "key" = "ctrl+p";
    "command" = "workbench.action.togglePanel";
  }
  {
    "key" = "space l n";
    "args" = " ln";
    "command" = "vscode-neovim.send";
    "when" =
      "(editorFocus || !searchInputBoxFocus) && !inputFocus && neovim.init && neovim.mode == 'normal'";
  }
  {
    "key" = "space ";
    "args" = " ";
    "command" = "vscode-neovim.send";
    "when" =
      "(editorFocus || !searchInputBoxFocus) && !inputFocus && neovim.init && neovim.mode == 'normal'";
  }
  {
    "key" = "ctrl+e";
    "args" = "<c-e>";
    "command" = "vscode-neovim.send";
  }
  {
    "key" = "space f f";
    "args" = " ff";
    "command" = "vscode-neovim.send";
    "when" =
      "(editorFocus || !searchInputBoxFocus) && !inputFocus && neovim.init && neovim.mode == 'normal'";
  }
  {
    "key" = "space f s";
    "args" = " fs";
    "command" = "vscode-neovim.send";
    "when" =
      "(editorFocus || !searchInputBoxFocus) && !inputFocus && neovim.init && neovim.mode == 'normal'";
  }
  {
    "key" = "space f t";
    "args" = " ft";
    "command" = "vscode-neovim.send";
    "when" =
      "(editorFocus || !searchInputBoxFocus) && !inputFocus && neovim.init && neovim.mode == 'normal'";
  }
  {
    "key" = "space f x";
    "args" = " fx";
    "command" = "vscode-neovim.send";
    "when" =
      "(editorFocus || !searchInputBoxFocus) && !inputFocus && neovim.init && neovim.mode == 'normal'";
  }
  {
    "key" = "space f p";
    "args" = " fp";
    "command" = "vscode-neovim.send";
    "when" =
      "(editorFocus || !searchInputBoxFocus) && !inputFocus && neovim.init && neovim.mode == 'normal'";
  }
  {
    "key" = "space c";
    "args" = " c";
    "command" = "vscode-neovim.send";
    "when" =
      "(editorFocus || !searchInputBoxFocus) && !inputFocus && neovim.init && neovim.mode == 'normal'";
  }
  {
    "key" = "space s";
    "args" = " s";
    "command" = "vscode-neovim.send";
    "when" =
      "(editorFocus || !searchInputBoxFocus) && !inputFocus && neovim.init && neovim.mode == 'normal'";
  }
  {
    "key" = "space d";
    "args" = " d";
    "command" = "vscode-neovim.send";
    "when" =
      "(editorFocus || !searchInputBoxFocus) && !inputFocus && neovim.init && neovim.mode == 'normal'";
  }
  {
    "key" = "space r o";
    "args" = " ro";
    "command" = "vscode-neovim.send";
    "when" =
      "(editorFocus || !searchInputBoxFocus) && !inputFocus && neovim.init && neovim.mode == 'normal'";
  }
  {
    "key" = "space space";
    "args" = "  ";
    "command" = "vscode-neovim.send";
    "when" =
      "(editorFocus || !searchInputBoxFocus) && !inputFocus && neovim.init && neovim.mode == 'normal'";
  }
  {
    "key" = "space f c";
    "args" = " fc";
    "command" = "vscode-neovim.send";
    "when" =
      "(editorFocus || !searchInputBoxFocus) && !inputFocus && neovim.init && neovim.mode == 'normal'";
  }
  {
    "key" = "space f l";
    "args" = " fl";
    "command" = "vscode-neovim.send";
    "when" =
      "(editorFocus || !searchInputBoxFocus) && !inputFocus && neovim.init && neovim.mode == 'normal'";
  }
  {
    "key" = "space r r";
    "command" = "vscode-neovim.restart";
    "when" =
      "(editorFocus || !searchInputBoxFocus) && !inputFocus && neovim.init && neovim.mode == 'normal'";
  }
  {
    "key" = "space s r";
    "args" = " sr";
    "command" = "vscode-neovim.send";
    "when" =
      "(editorFocus || !searchInputBoxFocus) && !inputFocus && neovim.init && neovim.mode == 'normal'";
  }
  {
    "key" = "space w c";
    "args" = " wc";
    "command" = "vscode-neovim.send";
    "when" =
      "(editorFocus || !searchInputBoxFocus) && !inputFocus && neovim.init && neovim.mode == 'normal'";
  }
  {
    "key" = "space f o";
    "args" = " wc";
    "command" = "vscode-neovim.send";
    "when" =
      "(editorFocus || !searchInputBoxFocus) && !inputFocus && neovim.init && neovim.mode == 'normal'";
  }
  {
    "key" = "space o t";
    "args" = " ot";
    "command" = "vscode-neovim.send";
    "when" =
      "(editorFocus || !searchInputBoxFocus) && !inputFocus && neovim.init && neovim.mode == 'normal'";
  }
  {
    "key" = "space c n";
    "args" = " cn";
    "command" = "vscode-neovim.send";
    "when" =
      "(editorFocus || !searchInputBoxFocus) && !inputFocus && neovim.init && neovim.mode == 'normal'";
  }
  {
    "key" = "space g s y";
    "args" = " gsy";
    "command" = "vscode-neovim.send";
    "when" =
      "(editorFocus || !searchInputBoxFocus) && !inputFocus && neovim.init && neovim.mode == 'normal'";
  }
  {
    "key" = "space g s a";
    "args" = " gsa";
    "command" = "vscode-neovim.send";
    "when" =
      "(editorFocus || !searchInputBoxFocus) && !inputFocus && neovim.init && neovim.mode == 'normal'";
  }
  {
    "key" = "space g s t";
    "args" = " gst";
    "command" = "vscode-neovim.send";
    "when" =
      "(editorFocus || !searchInputBoxFocus) && !inputFocus && neovim.init && neovim.mode == 'normal'";
  }
  {
    "key" = "space g b";
    "args" = " gb";
    "command" = "vscode-neovim.send";
    "when" =
      "(editorFocus || !searchInputBoxFocus) && !inputFocus && neovim.init && neovim.mode == 'normal'";
  }
  {
    "key" = "space g c";
    "args" = " gc";
    "command" = "vscode-neovim.send";
    "when" =
      "(editorFocus || !searchInputBoxFocus) && !inputFocus && neovim.init && neovim.mode == 'normal'";
  }
  {
    "key" = "space g f";
    "args" = " gf";
    "command" = "vscode-neovim.send";
    "when" =
      "(editorFocus || !searchInputBoxFocus) && !inputFocus && neovim.init && neovim.mode == 'normal'";
  }
  {
    "key" = "space g g";
    "args" = " gg";
    "command" = "vscode-neovim.send";
    "when" =
      "(editorFocus || !searchInputBoxFocus) && !inputFocus && neovim.init && neovim.mode == 'normal'";
  }
  {
    "key" = "space g m";
    "args" = " gm";
    "command" = "vscode-neovim.send";
    "when" =
      "(editorFocus || !searchInputBoxFocus) && !inputFocus && neovim.init && neovim.mode == 'normal'";
  }
  {
    "key" = "space g d";
    "args" = " gd";
    "command" = "vscode-neovim.send";
    "when" =
      "(editorFocus || !searchInputBoxFocus) && !inputFocus && neovim.init && neovim.mode == 'normal'";
  }
  {
    "key" = "space p r";
    "args" = " pr";
    "command" = "vscode-neovim.send";
    "when" =
      "(editorFocus || !searchInputBoxFocus) && !inputFocus && neovim.init && neovim.mode == 'normal'";
  }
  {
    "key" = "space j s";
    "args" = " js";
    "command" = "vscode-neovim.send";
    "when" =
      "(editorFocus || !searchInputBoxFocus) && !inputFocus && neovim.init && neovim.mode == 'normal'";
  }
  {
    "key" = "space j f";
    "args" = " jf";
    "command" = "vscode-neovim.send";
    "when" =
      "(editorFocus || !searchInputBoxFocus) && !inputFocus && neovim.init && neovim.mode == 'normal'";
  }
  {
    "key" = "space j a";
    "args" = " ja";
    "command" = "vscode-neovim.send";
    "when" =
      "(editorFocus || !searchInputBoxFocus) && !inputFocus && neovim.init && neovim.mode == 'normal'";
  }
  {
    "key" = "space j c";
    "args" = " jc";
    "command" = "vscode-neovim.send";
    "when" =
      "(editorFocus || !searchInputBoxFocus) && !inputFocus && neovim.init && neovim.mode == 'normal'";
  }
  {
    "key" = "space k";
    "args" = " k";
    "command" = "vscode-neovim.send";
    "when" =
      "(editorFocus || !searchInputBoxFocus) && !inputFocus && neovim.init && neovim.mode == 'normal'";
  }
  {
    "key" = "backspace";
    "args" = "<BS>";
    "command" = "vscode-neovim.send";
    "when" =
      "(editorFocus || !searchInputBoxFocus) && !inputFocus && neovim.init && neovim.mode == 'normal'";
  }
  {
    "key" = "ctrl+;";
    "command" = "workbench.action.focusRightGroup";
  }
  {
    "key" = "ctrl+l";
    "command" = "workbench.action.focusLeftGroup";
  }
  {
    "key" = "ctrl+k";
    "command" = "workbench.action.navigateDown";
    "when" = "!terminalFocus";
  }
  {
    "key" = "ctrl+j";
    "command" = "workbench.action.navigateUp";
  }
  {
    "key" = "ctrl+l";
    "command" = "-workbench.action.chat.newChat";
    "when" = "chatIsEnabled && inChat";
  }
  {
    "key" = "ctrl+m ;";
    "command" = "aipopup.action.modal.generate";
    "when" =
      "editorFocus && !composerBarIsVisible && !composerControlPanelIsVisible";
  }
  {
    "key" = "ctrl+k";
    "command" = "-aipopup.action.modal.generate";
    "when" =
      "editorFocus && !composerBarIsVisible && !composerControlPanelIsVisible";
  }
  {
    "key" = "ctrl+b";
    "command" = "aichat.newchataction";
  }
  {
    "key" = "ctrl+l";
    "command" = "-aichat.newchataction";
  }
  {
    "key" = "ctrl+b";
    "command" = "-workbench.action.toggleSidebarVisibility";
  }
  {
    "key" = "ctrl+k m";
    "command" = "-pr.makeSuggestion";
    "when" = "commentEditorFocused";
  }
  {
    "key" = "ctrl+k 7";
    "command" = "-orta.vscode-twoslash-queries.insert-inline-query";
    "when" = "editorTextFocus";
  }
  {
    "key" = "ctrl+k ctrl+shift+c";
    "command" = "-java.view.package.copyRelativeFilePath";
    "when" =
      "focusedView == 'javaProjectExplorer' && java:serverMode == 'Standard'";
  }
  {
    "key" = "ctrl+k v";
    "command" = "-markdown-preview-enhanced.openPreviewToTheSide";
    "when" = "editorLangId == 'markdown'";
  }
  {
    "key" = "ctrl+k v";
    "command" = "-markdown.showPreviewToSide";
    "when" = "!notebookEditorFocused && editorLangId == 'markdown'";
  }
  {
    "key" = "ctrl+k p";
    "command" = "-pandoc.render";
    "when" = "editorTextFocus && editorLangId == 'markdown'";
  }
  {
    "key" = "ctrl+k 6";
    "command" = "-orta.vscode-twoslash-queries.insert-twoslash-query";
    "when" = "editorTextFocus";
  }
  {
    "key" = "ctrl+k v";
    "command" = "-markdown.extension.closePreview";
    "when" = "activeWebviewPanelId == 'markdown.preview'";
  }
  {
    "key" = "ctrl+k ctrl+r";
    "command" = "-git.revertSelectedRanges";
    "when" = "isInDiffEditor && !operationInProgress";
  }
  {
    "key" = "ctrl+k ctrl+shift+s";
    "command" = "-easySnippet.run";
  }
  {
    "key" = "ctrl+k ctrl+alt+s";
    "command" = "-git.stageSelectedRanges";
    "when" = "isInDiffEditor && !operationInProgress";
  }
  {
    "key" = "ctrl+k ctrl+n";
    "command" = "-git.unstageSelectedRanges";
    "when" = "isInDiffEditor && !operationInProgress";
  }
  {
    "key" = "ctrl+k ctrl+n";
    "command" = "workbench.action.focusSideBar";
    "when" = "isInDiffEditor && !operationInProgress";
  }
  {
    "key" = "ctrl+s";
    "command" = "-workbench.action.files.save";
  }
  {
    "key" = "ctrl+m e";
    "command" = "-workbench.files.action.focusOpenEditorsView";
    "when" = "workbench.explorer.openEditorsView.active";
  }
  {
    "key" = "ctrl+j";
    "command" = "-workbench.action.togglePanel";
  }
  {
    "key" = "ctrl+g";
    "command" = "-editor.action.simpleInlineDiffs.acceptAll";
    "when" = "editorTextFocus && hasDisplayedSimpleDiff";
  }
  {
    "key" = "ctrl+g";
    "command" = "-workbench.action.gotoLine";
  }
  {
    "key" = "ctrl+g";
    "command" = "-hexEditor.goToOffset";
    "when" = "activeCustomEditorId == 'hexEditor.hexedit'";
  }
  {
    "key" = "ctrl+g";
    "command" = "-workbench.action.terminal.goToRecentDirectory";
    "when" =
      "terminalFocus && terminalHasBeenCreated || terminalFocus && terminalProcessSupported";
  }
  {
    "key" = "ctrl+shift+f";
    "command" = "-workbench.action.findInFiles";
  }
  {
    "key" = "space";
    "command" = "-list.stickyScrolltoggleExpand";
    "when" = "treestickyScrollFocused";
  }
  {
    "key" = "space";
    "command" = "-list.toggleExpand";
    "when" = "listFocus && !inputFocus && !treestickyScrollFocused";
  }
  {
    "key" = "shift+k";
    "command" = "list.expandSelectionDown";
    "when" =
      "listFocus && listSupportsMultiselect && !inputFocus && !treestickyScrollFocused";
  }
  {
    "key" = "shift+down";
    "command" = "-list.expandSelectionDown";
    "when" =
      "listFocus && listSupportsMultiselect && !inputFocus && !treestickyScrollFocused";
  }
  {
    "key" = "shift+j";
    "command" = "list.expandSelectionUp";
    "when" =
      "listFocus && listSupportsMultiselect && !inputFocus && !treestickyScrollFocused";
  }
  {
    "key" = "shift+up";
    "command" = "-list.expandSelectionUp";
    "when" =
      "listFocus && listSupportsMultiselect && !inputFocus && !treestickyScrollFocused";
  }
  {
    "key" = "d";
    "command" = "search.action.remove";
    "when" = "fileMatchOrMatchFocus && searchViewletVisible";
  }
  {
    "key" = "delete";
    "command" = "-search.action.remove";
    "when" = "fileMatchOrMatchFocus && searchViewletVisible";
  }
  {
    "key" = "z m";
    "command" = "search.action.collapseSearchResults";
    "when" = "fileMatchOrMatchFocus";
  }
  {
    "key" = "ctrl+m down";
    "command" = "-workbench.action.moveActiveEditorGroupDown";
  }
  {
    "key" = "ctrl+m left";
    "command" = "-workbench.action.moveActiveEditorGroupLeft";
  }
  {
    "key" = "ctrl+m right";
    "command" = "-workbench.action.moveActiveEditorGroupRight";
  }
  {
    "key" = "ctrl+m up";
    "command" = "-workbench.action.moveActiveEditorGroupUp";
  }
  {
    "key" = "ctrl+shift+k";
    "command" = "-aipopup.action.modal.generate";
    "when" =
      "editorFocus && !composerBarIsVisible && !composerControlPanelIsVisible";
  }
  {
    "key" = "ctrl+shift+k";
    "command" = "-editor.action.deleteLines";
    "when" = "textInputFocus && !editorReadonly";
  }
  {
    "key" = "ctrl+shift+j";
    "command" = "-aiSettings.action.open";
    "when" = "!isSettingsPaneOpen";
  }
  {
    "key" = "ctrl+shift+j";
    "command" = "-aiSettings.action.openhidden";
    "when" = "!isSettingsPaneOpen";
  }
  {
    "key" = "ctrl+shift+l";
    "command" = "-aichat.insertselectionintochat";
  }
  {
    "key" = "ctrl+shift+l";
    "command" = "-editor.action.selectHighlights";
    "when" = "editorFocus";
  }
  {
    "key" = "ctrl+shift+l";
    "command" = "-selectAllSearchEditorMatches";
    "when" = "inSearchEditor";
  }
  {
    "key" = "ctrl+shift+l";
    "command" = "-addCursorsAtSearchResults";
    "when" = "fileMatchOrMatchFocus && searchViewletVisible";
  }
  {
    "key" = "ctrl+shift+o";
    "command" = "-workbench.action.gotoSymbol";
    "when" = "!accessibilityHelpIsShown && !accessibleViewIsShown";
  }
  {
    "key" = "ctrl+shift+o";
    "command" = "-editor.action.accessibleViewGoToSymbol";
    "when" =
      "accessibilityHelpIsShown && accessibleViewGoToSymbolSupported || accessibleViewGoToSymbolSupported && accessibleViewIsShown";
  }
  {
    "key" = "ctrl+shift+o";
    "command" = "-workbench.action.terminal.openDetectedLink";
    "when" = "terminalFocus && terminalHasBeenCreated";
  }
  {
    "key" = "ctrl+shift+j";
    "command" = "workbench.action.moveEditorToAboveGroup";
  }
  {
    "key" = "ctrl+shift+;";
    "command" = "workbench.action.moveEditorToRightGroup";
  }
  {
    "key" = "ctrl+shift+k";
    "command" = "workbench.action.moveEditorToBelowGroup";
  }
  {
    "key" = "ctrl+shift+l";
    "command" = "workbench.action.moveEditorToLeftGroup";
  }
  {
    "key" = "ctrl+m i";
    "command" = "-inlineChat.start";
    "when" = "editorFocus && inlineChatHasProvider && !editorReadonly";
  }
  {
    "key" = "g r";
    "command" = "gitlens.views.scm.grouped.remotes";
    "when" =
      "config.gitlens.views.scm.grouped.views.remotes && focusedView == 'gitlens.views.scm.grouped' && !inputFocus";
  }
  {
    "key" = "3";
    "command" = "-gitlens.views.scm.grouped.remotes";
    "when" =
      "config.gitlens.views.scm.grouped.views.remotes && focusedView == 'gitlens.views.scm.grouped'";
  }
  {
    "key" = "g s";
    "command" = "gitlens.views.scm.grouped.stashes";
    "when" =
      "config.gitlens.views.scm.grouped.views.stashes && focusedView == 'gitlens.views.scm.grouped' && !inputFocus";
  }
  {
    "key" = "4";
    "command" = "-gitlens.views.scm.grouped.stashes";
    "when" =
      "config.gitlens.views.scm.grouped.views.stashes && focusedView == 'gitlens.views.scm.grouped'";
  }
  {
    "key" = "g b";
    "command" = "gitlens.views.scm.grouped.branches";
    "when" =
      "config.gitlens.views.scm.grouped.views.branches && focusedView == 'gitlens.views.scm.grouped' && !inputFocus";
  }
  {
    "key" = "2";
    "command" = "-gitlens.views.scm.grouped.branches";
    "when" =
      "config.gitlens.views.scm.grouped.views.branches && focusedView == 'gitlens.views.scm.grouped'";
  }
  {
    "key" = "g c";
    "command" = "gitlens.views.scm.grouped.commits";
    "when" =
      "config.gitlens.views.scm.grouped.views.commits && focusedView == 'gitlens.views.scm.grouped' && !inputFocus";
  }
  {
    "key" = "1";
    "command" = "-gitlens.views.scm.grouped.commits";
    "when" =
      "config.gitlens.views.scm.grouped.views.commits && focusedView == 'gitlens.views.scm.grouped'";
  }
  {
    "key" = "g p";
    "command" = "gitlens.views.scm.grouped.repositories";
    "when" =
      "config.gitlens.views.scm.grouped.views.repositories && focusedView == 'gitlens.views.scm.grouped' && !inputFocus";
  }
  {
    "key" = "8";
    "command" = "-gitlens.views.scm.grouped.repositories";
    "when" =
      "config.gitlens.views.scm.grouped.views.repositories && focusedView == 'gitlens.views.scm.grouped'";
  }
  {
    "key" = "ctrl+p";
    "command" = "-expandLineSelection";
    "when" = "textInputFocus";
  }
  {
    "key" = "ctrl+p";
    "command" = "-workbench.action.quickOpen";
  }
  {
    "key" = "ctrl+q";
    "command" = "-workbench.action.quickOpenNavigateNextInViewPicker";
    "when" = "inQuickOpen && inViewsPicker";
  }
  {
    "key" = "ctrl+q";
    "command" = "-workbench.action.quickOpenView";
  }
  {
    "key" = "ctrl+q";
    "command" = "-vscode-neovim.send";
    "when" =
      "editorTextFocus && neovim.ctrlKeysNormal.q && neovim.init && neovim.mode != 'insert' && editorLangId not in 'neovim.editorLangIdExclusions'";
  }
  {
    "key" = "ctrl+w";
    "command" = "-vscode-neovim.send";
    "when" =
      "editorTextFocus && neovim.ctrlKeysNormal.w && neovim.init && neovim.mode != 'insert' && editorLangId not in 'neovim.editorLangIdExclusions'";
  }
  {
    "key" = "shift+k";
    "command" = "list.showHover";
    "when" = "listFocus && !inputFocus && !treestickyScrollFocused";
  }
  {
    "key" = "ctrl+m ctrl+i";
    "command" = "-list.showHover";
    "when" = "listFocus && !inputFocus && !treestickyScrollFocused";
  }
  {
    "key" = "shift+escape";
    "command" = "-closeDirtyDiff";
    "when" = "dirtyDiffVisible";
  }
  {
    "key" = "alt+f3";
    "command" = "-editor.action.dirtydiff.next";
    "when" = "editorTextFocus && !textCompareEditorActive";
  }
  {
    "key" = "shift+alt+f3";
    "command" = "-editor.action.dirtydiff.previous";
    "when" = "editorTextFocus && !textCompareEditorActive";
  }
  {
    "key" = "shift+r";
    "command" = "git.revertSelectedRanges";
    "when" =
      "editorFocus && neovim.init && neovim.mode == 'visual' || dirtyDiffVisible";
  }
  {
    "key" = "l";
    "command" = "list.toggleSelection";
    "when" = "listFocus && !inputFocus && !treestickyScrollFocused";
  }
  {
    "key" = "ctrl+shift+enter";
    "command" = "-list.toggleSelection";
    "when" = "listFocus && !inputFocus && !treestickyScrollFocused";
  }
  {
    "key" = "l";
    "command" = "-list.select";
    "when" = "listFocus && !inputFocus";
  }
  {
    "key" = "ctrl+shift+k";
    "command" = "keybindings.editor.recordSearchKeys";
    "when" = "inKeybindings && inKeybindingsSearch";
  }
  {
    "key" = "alt+k";
    "command" = "-keybindings.editor.recordSearchKeys";
    "when" = "inKeybindings && inKeybindingsSearch";
  }
  {
    "key" = "ctrl+shift+d";
    "command" = "workbench.action.compareEditor.nextChange";
    "when" = "textCompareEditorVisible";
  }
  {
    "key" = "alt+f5";
    "command" = "-workbench.action.compareEditor.nextChange";
    "when" = "textCompareEditorVisible";
  }
  {
    "key" = "ctrl+shift+u";
    "command" = "workbench.action.compareEditor.previousChange";
    "when" = "textCompareEditorVisible";
  }
  {
    "key" = "shift+alt+f5";
    "command" = "-workbench.action.compareEditor.previousChange";
    "when" = "textCompareEditorVisible";
  }
  {
    "key" = "ctrl+shift+d";
    "command" = "-workbench.view.debug";
    "when" = "viewContainer.workbench.view.debug.enabled";
  }
  {
    "key" = "ctrl+m l";
    "command" = "workbench.panel.aichat.view.focus";
  }
  {
    "key" = "shift+win+c";
    "command" = "-vscode-wezterm.openTerminal";
  }
  {
    "key" = "ctrl+t";
    "command" = "-workbench.action.showAllSymbols";
  }
  {
    "key" = "ctrl+e";
    "command" = "-workbench.action.quickOpenNavigateNextInFilePicker";
    "when" = "inFilesPicker && inQuickOpen";
  }
  {
    "key" = "ctrl+e";
    "command" = "-editor.action.toggleScreenReaderAccessibilityMode";
    "when" = "accessibilityHelpIsShown";
  }
  {
    "key" = "ctrl+u";
    "command" = "multiCommand.halfListUp";
    "when" = "listFocus || inQuickOpen || inQuickInput || inCommandsPicker";
  }
  {
    "key" = "ctrl+d";
    "command" = "multiCommand.halfListDown";
    "when" = "listFocus || inQuickOpen || inQuickInput || inCommandsPicker";
  }
  {
    "key" = "ctrl+f";
    "command" = "-editor.action.pageDownHover";
    "when" = "editorHoverFocused";
  }
  {
    "key" = "ctrl+f";
    "command" = "-vscode-neovim.send";
    "when" =
      "editorTextFocus && neovim.ctrlKeysInsert.f && neovim.init && neovim.mode == 'insert' && editorLangId not in 'neovim.editorLangIdExclusions'";
  }
  {
    "key" = "ctrl+f";
    "command" = "-vscode-neovim.ctrl-f";
    "when" =
      "editorTextFocus && neovim.ctrlKeysNormal.f && neovim.init && neovim.mode != 'insert' && editorLangId not in 'neovim.editorLangIdExclusions'";
  }
  {
    "key" = "ctrl+shift+t";
    "command" = "-workbench.action.reopenClosedEditor";
  }
  {
    "key" = "ctrl+shift+.";
    "command" = "-breadcrumbs.focusAndSelect";
    "when" = "breadcrumbsPossible && breadcrumbsVisible";
  }
  {
    "key" = "l";
    "command" = "breadcrumbs.focusPrevious";
    "when" = "breadcrumbsActive";
  }
  {
    "key" = ";";
    "command" = "breadcrumbs.focusNext";
    "when" = "breadcrumbsActive";
  }
  {
    "key" = "ctrl+shift+;";
    "command" = "-breadcrumbs.focus";
    "when" = "breadcrumbsPossible && breadcrumbsVisible";
  }
  {
    "key" = "ctrl+u";
    "command" = "-list.focusPageUp";
    "when" = "listFocus && !inputFocus";
  }
  {
    "key" = "backspace";
    "command" = "-markdown.extension.onBackspaceKey";
  }
  {
    "key" = "tab";
    "command" = "-markdown.extension.onTabKey";
  }
  {
    "key" = "tab";
    "command" = "-acceptSelectedSuggestion";
    "when" =
      "suggestWidgetHasFocusedSuggestion && suggestWidgetVisible && textInputFocus";
  }
  {
    "key" = "tab";
    "command" = "-insertBestCompletion";
    "when" =
      "atEndOfWord && textInputFocus && !hasOtherSuggestions && !inSnippetMode && !suggestWidgetVisible && config.editor.tabCompletion == 'on'";
  }
  {
    "key" = "tab";
    "command" = "-insertNextSuggestion";
    "when" =
      "hasOtherSuggestions && textInputFocus && !inSnippetMode && !suggestWidgetVisible && config.editor.tabCompletion == 'on'";
  }
  {
    "key" = "tab";
    "command" = "-insertSnippet";
    "when" =
      "editorTextFocus && hasSnippetCompletions && !editorTabMovesFocus && !inSnippetMode";
  }
  {
    "key" = "ctrl+e";
    "command" = "-vscode-neovim.ctrl-e";
    "when" =
      "editorTextFocus && neovim.ctrlKeysNormal.e && neovim.init && neovim.mode != 'insert' && editorLangId not in 'neovim.editorLangIdExclusions'";
  }
  {
    "key" = "ctrl+w";
    "command" = "-composer.closeComposerTab";
  }
  {
    "key" = "ctrl+right";
    "command" = "-vscode-neovim.send";
    "when" =
      "editorTextFocus && neovim.ctrlKeysNormal.right && neovim.init && neovim.mode != 'insert' && editorLangId not in 'neovim.editorLangIdExclusions'";
  }
  {
    "key" = "ctrl+right";
    "command" = "-vscode-neovim.send";
    "when" =
      "editorTextFocus && neovim.ctrlKeysInsert.right && neovim.init && neovim.mode == 'insert' && editorLangId not in 'neovim.editorLangIdExclusions'";
  }
  {
    "key" = "ctrl+i";
    "command" = "-composer.startComposerPrompt";
  }
  {
    "key" = "ctrl+m ctrl+left";
    "command" = "-workbench.action.focusLeftGroup";
  }
  {
    "key" = "ctrl+m ctrl+right";
    "command" = "-workbench.action.focusRightGroup";
  }
  {
    "key" = "ctrl+l";
    "command" = "-workbench.action.chat.newChat";
    "when" = "chatIsEnabled && inChat && chatLocation != 'editing-session'";
  }
  {
    "key" = "ctrl+l";
    "command" = "-workbench.action.chat.newEditSession";
    "when" =
      "chatEditingParticipantRegistered && chatIsEnabled && inChat && chatLocation == 'editing-session'";
  }
  {
    "key" = "ctrl+l";
    "command" = "-vscode-neovim.send";
    "when" =
      "editorTextFocus && neovim.ctrlKeysNormal.l && neovim.init && neovim.mode != 'insert' && editorLangId not in 'neovim.editorLangIdExclusions'";
  }
  {
    "key" = "ctrl+l";
    "command" = "-vscode-neovim.send";
    "when" =
      "editorTextFocus && neovim.ctrlKeysInsert.l && neovim.init && neovim.mode == 'insert' && editorLangId not in 'neovim.editorLangIdExclusions'";
  }
  {
    "key" = "ctrl+l";
    "command" = "-composer.sendToAgent";
    "when" = "editorHasPromptBar && editorPromptBarFocused";
  }
  {
    "key" = "ctrl+;";
    "command" = "-workbench.action.backgroundComposer.openControlPanel2";
    "when" = "backgroundComposerEnabled";
  }
  {
    "key" = "ctrl+; ctrl+x";
    "command" = "-testing.cancelRun";
  }
  {
    "key" = "ctrl+; ctrl+a";
    "command" = "-testing.debugAll";
  }
  {
    "key" = "ctrl+; ctrl+e";
    "command" = "-testing.debugFailTests";
  }
  {
    "key" = "ctrl+; ctrl+l";
    "command" = "-testing.debugLastRun";
  }
  {
    "key" = "ctrl+; ctrl+c";
    "command" = "-testing.debugAtCursor";
    "when" = "editorTextFocus";
  }
  {
    "key" = "ctrl+; ctrl+f";
    "command" = "-testing.debugCurrentFile";
    "when" = "editorTextFocus";
  }
  {
    "key" = "ctrl+; ctrl+m";
    "command" = "-testing.openOutputPeek";
  }
  {
    "key" = "ctrl+; ctrl+r";
    "command" = "-testing.refreshTests";
    "when" = "testing.canRefresh";
  }
  {
    "key" = "ctrl+; e";
    "command" = "-testing.reRunFailTests";
  }
  {
    "key" = "ctrl+; l";
    "command" = "-testing.reRunLastRun";
  }
  {
    "key" = "ctrl+; ctrl+shift+l";
    "command" = "-testing.coverageLastRun";
  }
  {
    "key" = "ctrl+; a";
    "command" = "-testing.runAll";
  }
  {
    "key" = "ctrl+; ctrl+shift+a";
    "command" = "-testing.coverageAll";
  }
  {
    "key" = "ctrl+; c";
    "command" = "-testing.runAtCursor";
    "when" = "editorTextFocus";
  }
  {
    "key" = "ctrl+; ctrl+shift+c";
    "command" = "-testing.coverageAtCursor";
    "when" = "editorTextFocus";
  }
  {
    "key" = "ctrl+; f";
    "command" = "-testing.runCurrentFile";
    "when" = "editorTextFocus";
  }
  {
    "key" = "ctrl+; ctrl+shift+f";
    "command" = "-testing.coverageCurrentFile";
    "when" = "editorTextFocus";
  }
  {
    "key" = "ctrl+; ctrl+o";
    "command" = "-testing.showMostRecentOutput";
    "when" = "testing.hasAnyResults";
  }
  {
    "key" = "ctrl+; ctrl+shift+i";
    "command" = "-testing.toggleInlineCoverage";
  }
  {
    "key" = "ctrl+; ctrl+i";
    "command" = "-testing.toggleInlineTestOutput";
  }
  {
    "key" = "ctrl+w";
    "command" = "-workbench.action.closeGroup";
    "when" = "activeEditorGroupEmpty && multipleEditorGroups";
  }
  {
    "key" = "ctrl+shift+p";
    "command" = "workbench.action.showCommands";
  }
  {
    "key" = "shift+cmd+p";
    "command" = "-workbench.action.showCommands";
  }
  {
    "key" = "ctrl+pagedown";
    "command" = "workbench.action.nextEditor";
  }
  {
    "key" = "shift+cmd+]";
    "command" = "-workbench.action.nextEditor";
  }
  {
    "key" = "ctrl+pageup";
    "command" = "workbench.action.previousEditor";
  }
  {
    "key" = "shift+cmd+[";
    "command" = "-workbench.action.previousEditor";
  }
  {
    "key" = "ctrl+pageup";
    "command" = "-scrollLineUp";
    "when" = "textInputFocus";
  }
  {
    "key" = "ctrl+pagedown";
    "command" = "-scrollLineDown";
    "when" = "textInputFocus";
  }
  {
    "key" = "ctrl+f";
    "command" = "actions.find";
    "when" = "editorFocus || editorIsOpen";
  }
  {
    "key" = "cmd+f";
    "command" = "-actions.find";
    "when" = "editorFocus || editorIsOpen";
  }
  {
    "key" = "ctrl+.";
    "command" = "editor.action.quickFix";
    "when" =
      "editorHasCodeActionsProvider && textInputFocus && !editorReadonly";
  }
  {
    "key" = "cmd+.";
    "command" = "-editor.action.quickFix";
    "when" =
      "editorHasCodeActionsProvider && textInputFocus && !editorReadonly";
  }
  {
    "key" = "k";
    "command" = "-list.focusUp";
    "when" = "notebookEditorFocused && !inputFocus && !notebookOutputFocused";
  }
  {
    "key" = "ctrl+q q";
    "args" = "<c-q><esc>";
    "command" = "vscode-neovim.send";
    "when" = "neovim.init && neovim.mode == 'cmdline'";
  }
  {
    "key" = "ctrl+q";
    "command" = "-workbench.action.quit";
  }
  {
    "key" = "ctrl+shift+t";
    "command" = "workbench.action.togglePanel";
  }
]
