{
  flake.cursorSettings =
    { pkgs, ... }:
    {
      "editor.suggestSelection" = "first";
      "terminal.integrated.useWslProfiles" = true;
      "eslint.workingDirectories" = [ { "mode" = "auto"; } ];
      "gitlens.currentLine.fontFamily" = "IosevkaTerm Nerd Font Mono";
      "gitlens.blame.fontFamily" = "IosevkaTerm Nerd Font Mono";
      "errorLens.fontFamily" = "IosevkaTerm Nerd Font Mono";
      "editor.fontFamily" = "IosevkaTerm Nerd Font Mono";
      "scm.inputFontFamily" = "IosevkaTerm Nerd Font Mono";
      "terminal.integrated.fontFamily" = "IosevkaTerm Nerd Font Mono";
      "debug.console.fontFamily" = "IosevkaTerm Nerd Font Mono";
      "editor.codeLensFontFamily" = "IosevkaTerm Nerd Font Mono";
      "editor.inlayHints.fontFamily" = "IosevkaTerm Nerd Font Mono";
      "editor.inlineSuggest.fontFamily" = "IosevkaTerm Nerd Font Mono";
      "notebook.output.fontFamily" = "IosevkaTerm Nerd Font Mono";
      "markdown.preview.fontFamily" = "IosevkaTerm Nerd Font Mono";
      "window.titleBarStyle" = "native";
      "window.customTitleBarVisibility" = "never";
      "workbench.colorCustomizations" = {
        "[Aura Soft Dark]" =
          let
            generalBackground = "#21202e";
          in
          {
            "editor.background" = generalBackground;
            "terminal.background" = generalBackground;
            "activityBar.background" = generalBackground;
            "statusBar.background" = generalBackground;
            "editorGroupHeader.tabsBackground" = generalBackground;
            "tab.inactiveBackground" = generalBackground;
            "editorSuggestWidget.background" = generalBackground;
            "sideBar.background" = generalBackground;
            "titleBar.activeBackground" = generalBackground;
            "terminalCursor.foreground" = "#b757ca";
            "editorInlayHint.foreground" = "#afafaf";
            "editorCursor.background" = "#21202e";
            "editorCursor.foreground" = "#b757ca";
            "editor.selectionBackground" = "#C234FF19";
            "editor.selectionHighlightBackground" = "#DAA8F019";
            "editorLineNumber.foreground" = "#954fa3";
            "editorLineNumber.activeForeground" = "#b757ca";
            "editorBracketMatch.border" = "#23384300";
            "editorBracketMatch.background" = "#57A7CA5F";
          };
      };
      "explorer.confirmDelete" = false;
      "explorer.confirmDragAndDrop" = false;
      "files.exclude" = {
        "**/.classpath" = true;
        "**/.project" = true;
        "**/.factorypath" = true;
      };
      "terminal.integrated.copyOnSelection" = true;
      "security.workspace.trust.untrustedFiles" = "open";
      "editor.fontLigatures" = false;
      "git.enableSmartCommit" = true;
      "git.confirmSync" = false;
      "editor.formatOnSave" = true;
      "notebook.formatOnSave.enabled" = true;
      "notebook.defaultFormatter" = "ms-python.black-formatter";
      "editor.inlineSuggest.enabled" = true;
      "window.commandCenter" = true;
      "terminal.integrated.fontSize" = 16;
      "vsicons.dontShowNewVersionMessage" = true;
      "notebook.output.scrolling" = true;
      "editor.tabSize" = 2;
      "explorer.compactFolders" = false;
      "editor.mouseWheelZoom" = true;
      "files.trimTrailingWhitespace" = true;
      "[markdown]" = {
        "editor.unicodeHighlight.ambiguousCharacters" = false;
        "editor.unicodeHighlight.invisibleCharacters" = false;
        "diffEditor.ignoreTrimWhitespace" = false;
        "editor.wordWrap" = "on";
        "editor.quickSuggestions" = {
          "comments" = "off";
          "strings" = "off";
          "other" = "off";
        };
        "editor.trimAutoWhitespace" = false;
        "editor.defaultFormatter" = "DavidAnson.vscode-markdownlint";
      };
      "editor.linkedEditing" = true;
      "terminal.integrated.defaultProfile.windows" = "Git Bash";
      "gitlens.gitCommands.skipConfirmations" = [
        "fetch:command"
        "stash-push:command"
        "switch:command"
        "branch-create:command"
      ];
      "typescript.updateImportsOnFileMove.enabled" = "always";
      "javascript.updateImportsOnFileMove.enabled" = "always";
      "[typescriptreact]" = {
        "editor.defaultFormatter" = "esbenp.prettier-vscode";
        "editor.inlayHints.enabled" = "off";
      };
      "git.openRepositoryInParentFolders" = "never";
      "[typescript]" = {
        "editor.defaultFormatter" = "esbenp.prettier-vscode";
        "editor.inlayHints.enabled" = "off";
      };
      "task.problemMatchers.neverPrompt" = {
        "shell" = true;
      };
      "gitlens.advanced.messages" = {
        "suppressCreatePullRequestPrompt" = true;
      };
      "typescript.suggest.paths" = false;
      "javascript.suggest.paths" = false;
      "eslint.validate" = [
        "typescript"
        "typescriptreact"
        "javascript"
        "javascriptreact"
        "vue"
      ];
      "path-intellisense.mappings" = {
        "@" = "\${workspaceRoot}/src";
      };
      "[vue]" = {
        "editor.defaultFormatter" = "esbenp.prettier-vscode";
      };
      "[javascript]" = {
        "editor.defaultFormatter" = "esbenp.prettier-vscode";
      };
      "[json]" = {
        "editor.defaultFormatter" = "esbenp.prettier-vscode";
      };
      "[jsonc]" = {
        "editor.defaultFormatter" = "esbenp.prettier-vscode";
      };
      "[css]" = {
        "editor.defaultFormatter" = "vscode.css-language-features";
      };
      "[html]" = {
        "editor.defaultFormatter" = "esbenp.prettier-vscode";
      };
      "[lua]" = {
        "editor.defaultFormatter" = "JohnnyMorganz.stylua";
      };
      "editor.bracketPairColorization.enabled" = true;
      "window.zoomLevel" = 1;
      "redhat.telemetry.enabled" = true;
      "files.associations" = {
        "*.rmd" = "markdown";
        "*.css" = "tailwindcss";
      };
      "editor.inlineSuggest.suppressSuggestions" = true;
      "update.mode" = "none";
      "errorLens.enabledDiagnosticLevels" = [
        "error"
        "info"
        "warning"
      ];
      "markdown.validate.enabled" = true;
      "terminal.integrated.env.linux" = { };
      "terminal.integrated.profiles.linux" = {
        "bash" = {
          "path" = "bash";
          "icon" = "terminal-bash";
        };
        "zsh" = {
          "path" = "zsh";
        };
        "fish" = {
          "path" = "fish";
        };
        "tmux" = {
          "path" = "tmux";
          "icon" = "terminal-tmux";
        };
        "pwsh" = {
          "path" = "pwsh";
          "icon" = "terminal-powershell";
        };
        "nushell" = {
          "path" = "nu";
          "icon" = "terminal-ubuntu";
        };
      };
      "terminal.integrated.defaultProfile.linux" = "nushell";
      "workbench.sideBar.location" = "right";
      "workbench.editor.customLabels.patterns" = {
        "*/**/index.*" = "/\${dirname} - index.\${extname}";
        "*/**/default.nix" = "/\${dirname} - default.\${extname}";
        "*/**/package.json" = "/\${dirname} - package.json";
        "**/app/**/page.tsx" = "/\${dirname} - page.tsx";
        "**/app/**/layout.tsx" = "/\${dirname} - layout.tsx";
        "**/app/**/_layout.tsx" = "/\${dirname} - _layout.tsx";
      };
      "workbench.editor.doubleClickTabToToggleEditorGroupSizes" = "maximize";
      "githubPullRequests.createOnPublishBranch" = "never";
      "extensions.experimental.affinity" = {
        "asvetliakov.vscode-neovim" = 1;
      };
      "vscode-neovim.neovimExecutablePaths.win32" = "C:\\tools\\neovim\\nvim-win64\\bin\\nvim.exe";
      "vscode-neovim.ctrlKeysForNormalMode" = [
        "a"
        "c"
        "d"
        "e"
        "f"
        "h"
        "i"
        "l"
        "m"
        "o"
        "r"
        "t"
        "u"
        "v"
        "x"
        "y"
        "z"
        "/"
        "]"
        "right"
        "left"
        "up"
        "down"
        "backspace"
        "delete"
        "w"
      ];
      "vscode-neovim.ctrlKeysForInsertMode" = [
        "c"
        "h"
        "j"
        "m"
        "o"
        "r"
        "t"
        "u"
        "w"
      ];
      "multiCommand.commands" = [
        {
          "command" = "multiCommand.halfPageUp";
          "sequence" = [
            {
              "command" = "vscode-neovim.send";
              "args" = "<C-u>";
            }
            # {
            #   "command" = "editorScroll";
            #   "args" = {
            #     "to" = "up";
            #     "by" = "halfPage";
            #   };
            # }
            # {
            #   "command" = "cursorMove";
            #   # "args" = {"to" = "viewPortTop";};
            #   "args" = {"to" = "viewPortCenter";};
            #   # "args" = {"to" = "viewPortIfOutside";};
            # }
            # {
            #   "command" = "vscode-neovim.send";
            #   "args" = "zz";
            # }
            # { "command" = "vscode-neovim.send"; "args" = "jk"; }
          ];
        }
        {
          "command" = "multiCommand.halfPageDown";
          "sequence" = [
            {
              "command" = "vscode-neovim.send";
              "args" = "<C-d>";
            }
            # {
            #   "command" = "editorScroll";
            #   "args" = {
            #     "to" = "down";
            #     "by" = "halfPage";
            #   };
            # }
            # {
            #   "command" = "cursorMove";
            #   # "args" = {"to" = "viewPortBottom";};
            #   "args" = {"to" = "viewPortCenter";};
            #   # "args" = {"to" = "viewPortIfOutside";};
            # }
            # {
            #   "command" = "vscode-neovim.send";
            #   "args" = "zz";
            # }
            # { "command" = "vscode-neovim.send"; "args" = "jk"; }
          ];
        }
        {
          "command" = "multiCommand.halfListUp";
          "sequence" = [
            "list.focusUp"
            "list.focusUp"
            "list.focusUp"
            "list.focusUp"
            "list.focusUp"
          ];
        }
        {
          "command" = "multiCommand.halfListDown";
          "sequence" = [
            "list.focusDown"
            "list.focusDown"
            "list.focusDown"
            "list.focusDown"
            "list.focusDown"
          ];
        }
      ];

      "terminal.integrated.smoothScrolling" = false;
      "editor.smoothScrolling" = false;
      "workbench.list.smoothScrolling" = false;
      "editor.cursorSmoothCaretAnimation" = "off";
      "editor.cursorSurroundingLines" = 4;
      "notebook.lineNumbers" = "on";
      "remote.autoForwardPortsSource" = "hybrid";
      "workbench.iconTheme" = "helium-icon-theme";
      "workbench.colorTheme" = "Aura Soft Dark";
      "[kotlin]" = {
        "editor.defaultFormatter" = "cstef.kotlin-formatter";
      };
      "editor.lineNumbers" = "relative";
      "workbench.tree.renderIndentGuides" = "none";
      "editor.guides.indentation" = false;
      "editor.renderWhitespace" = "none";
      "editor.renderLineHighlight" = "none";
      "editor.lightbulb.enabled" = "off";
      "editor.showFoldingControls" = "never";
      "editor.scrollbar.horizontal" = "hidden";
      "editor.scrollbar.vertical" = "hidden";
      "editor.overviewRulerBorder" = false;
      "editor.scrollbar.verticalScrollbarSize" = 20;
      "editor.cursorBlinking" = "solid";
      "workbench.editor.showTabs" = "single";
      "breadcrumbs.enabled" = true;
      "workbench.tips.enabled" = false;
      "files.insertFinalNewline" = true;
      "files.trimFinalNewlines" = true;
      "extensions.ignoreRecommendations" = true;
      "remote.SSH.remotePlatform" = {
        "workbench2" = "linux";
      };
      "javascript.inlayHints.functionLikeReturnTypes.enabled" = true;
      "javascript.inlayHints.parameterNames.enabled" = "all";
      "javascript.inlayHints.variableTypes.enabled" = true;
      "javascript.inlayHints.propertyDeclarationTypes.enabled" = true;
      "editor.inlayHints.padding" = true;
      "typescript.tsserver.nodePath" = "node";
      "files.autoSaveDelay" = 2000;
      "[java]" = {
        "editor.tabSize" = 4;
      };
      "[c]" = {
        "editor.wordBasedSuggestions" = "off";
        "editor.suggest.insertMode" = "replace";
        "editor.semanticHighlighting.enabled" = true;
        "editor.tabSize" = 4;
      };
      "workbench.editor.limit.enabled" = true;
      "workbench.editor.limit.perEditorGroup" = true;
      "workbench.editor.limit.value" = 8;
      "editor.minimap.enabled" = false;
      "gitlens.outputLevel" = "error";
      "cursor.cpp.disabledLanguages" = [ "scminput" ];
      "git.autofetch" = true;
      "sync.quietSync" = false;
      "sync.gist" = "56caf7d547529cdff341d35e01b4ff18";
      "gitlens.views.commits.files.layout" = "list";
      "githubPullRequests.remotes" = [
        "origin"
        "upstream"
        "github"
      ];
      "git.replaceTagsWhenPull" = true;
      "editor.wordWrap" = "on";
      "workbench.activityBar.location" = "hidden";
      "typescript.disableAutomaticTypeAcquisition" = true;
      "typescript.tsserver.log" = "off";
      "gitlens.views.searchAndCompare.files.layout" = "list";
      "[yaml]" = {
        "editor.defaultFormatter" = "esbenp.prettier-vscode";
      };
      "nix.enableLanguageServer" = true;
      "nix.serverPath" = "nixd";
      "gitlens.views.pullRequest.files.layout" = "list";
      "githubPullRequests.notifications" = "pullRequests";
      "githubPullRequests.fileListLayout" = "flat";
      "githubPullRequests.showPullRequestNumberInTree" = true;
      "githubPullRequests.defaultCommentType" = "review";
      "sync.forceUpload" = false;
      "sync.forceDownload" = false;
      "[firestorerules]" = {
        "editor.formatOnSave" = false;
      };
      "javascript.preferences.importModuleSpecifier" = "non-relative";
      "typescript.preferences.importModuleSpecifier" = "non-relative";
      "errorLens.enabled" = true;
      "cursor.cpp.enablePartialAccepts" = true;
      "githubPullRequests.pullBranch" = "never";
      "symbols.hidesExplorerArrows" = true;
      "tailwindCSS.classAttributes" = [
        "className"
        ".*ClassName"
      ];
      "tailwindCSS.classFunctions" = [
        "clsx"
        "cn"
        "cva"
      ];
      "stylua.styluaPath" = "/run/current-system/sw/bin/stylua";
      "emmet.showExpandedAbbreviation" = "never";
      "editor.codeActionsOnSave" = {
        "source.fixAll.biome" = "explicit";
        "source.organizeImports.biome" = "explicit";
      };
      "biome.lsp.bin" = "biome";
      "biome.requireConfiguration" = true;
      "biome.lsp.trace.server" = "verbose";
      "helium-icon-theme.hidesExplorerArrows" = true;
      "extensions.autoUpdate" = false;
      "cursor.composer.usageSummaryDisplay" = "always";
      "customizeUI.titleBar" = "frameless";
      "[shellscript]" = {
        "editor.defaultFormatter" = "mads-hartmann.bash-ide-vscode";
      };
      # "editor.cursorStyle" = "block";
      "editor.allowVariableFontsInAccessibilityMode" = true;
      "vscode-neovim.highlightGroups.highlights" = {
        "IncSearch" = {
          "backgroundColor" = "theme.editor.findMatchBackground";
        };
        "CurSearch" = {
          "backgroundColor" = "theme.editor.findMatchBackground";
        };
        "Search" = {
          "backgroundColor" = "theme.editor.findMatchHighlightBackground";
        };
        "Substitute" = {
          "backgroundColor" = "theme.editor.foreground";
          "color" = "theme.editor.background";
        };
        "LeapBackdrop" = {
          "color" = "#696969";
        };
      };
      "find-it-faster.general.useTerminalInEditor" = false;
      "find-it-faster.general.showMaximizedTerminal" = true;
      "find-it-faster.general.batTheme" = "Catppuccin Mocha";
      "find-it-faster.general.shellPathForTerminal" =
        "${pkgs.writeShellScriptBin "find-it-faster-terminal" ''
          SHELL=bash ${pkgs.bash}/bin/bash
        ''}/bin/find-it-faster-terminal";
      "find-it-faster.findFiles.previewWindowConfig" = "right:border-none:50%:+{2}+3/3";
      "find-it-faster.findWithinFiles.previewWindowConfig" = "right:border-none:50%:+{2}+3/3";
      "find-it-faster.findWithinFiles.fuzzRipgrepQuery" = true;
      "find-it-faster.findInActiveFile.previewWindowConfig" = "right:border-none:50%:+{2}+3/3";
      "find-it-faster.findInActiveFile.fuzzRipgrepQuery" = true;
      "terminal.integrated.tabs.enabled" = false;
      "githubPullRequests.commentExpandState" = "collapseAll";
      "typescript.native-preview.goMemLimit" = "2GiB";
      "editor.guides.highlightActiveBracketPair" = true;
    };
}
