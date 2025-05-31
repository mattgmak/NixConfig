{ config, lib, pkgs, pkgs-for-cursor ? pkgs, ... }:

with lib;

let
  cfg = config.programs.cursor-ui-style;

  # Use pkgs-for-cursor if available, otherwise fall back to pkgs
  cursorPkg = if pkgs-for-cursor ? code-cursor then
    pkgs-for-cursor.code-cursor
  else
    pkgs.code-cursor;

  # Status bar indicator JavaScript (adapted from vscode-custom-css extension for Cursor)
  cursorStatusBarJs = ''
    (function () {
      function patch() {
        const e1 = document.querySelector(".right-items");
        const e2 = document.querySelector(".right-items .__CUSTOM_CSS_JS_INDICATOR_CLS");
        if (e1 && !e2) {
          let e = document.createElement("div");
          e.id = "nixos.cursor-custom-css";
          e.title = "Custom CSS and JS (NixOS)";
          e.className = "statusbar-item right __CUSTOM_CSS_JS_INDICATOR_CLS";
          {
            const a = document.createElement("a");
            a.tabIndex = -1;
            a.className = 'statusbar-item-label';
            {
              const span = document.createElement("span");
              span.className = "codicon codicon-paintcan";
              a.appendChild(span);
            }
            e.appendChild(a);
          }
          e1.appendChild(e);
        }
      }
      setInterval(patch, 5000);
    })();
  '';

  # Create a modified cursor package with UI customizations
  modifiedCursor = pkgs.runCommand "cursor-ui-styled" {
    buildInputs = [ pkgs.jq pkgs.gnused ];
  } ''
    # Create output directory
    mkdir -p $out

    # Copy the original cursor
    cp -r ${cursorPkg}/* $out/
    chmod -R +w $out/

    # Find the main.js file for electron options
    MAIN_JS=""
    if [ -f "$out/share/cursor/resources/app/out/vs/code/electron-main/main.js" ]; then
      MAIN_JS="$out/share/cursor/resources/app/out/vs/code/electron-main/main.js"
    elif [ -f "$out/share/cursor/resources/app/out/main.js" ]; then
      MAIN_JS="$out/share/cursor/resources/app/out/main.js"
    else
      echo "Error: Could not find main.js in cursor installation"
      find $out -name "main.js" -type f
      exit 1
    fi

    echo "Found main.js at: $MAIN_JS"

    # Create backup of main.js
    cp "$MAIN_JS" "$MAIN_JS.original"

    ${optionalString (cfg.electron != { }) ''
      echo "Applying electron window options..."

      # Convert electron options to JSON string (removing outer braces)
      ELECTRON_JSON='${builtins.toJSON cfg.electron}'
      ELECTRON_OPTIONS=$(echo "$ELECTRON_JSON" | sed 's/^{//;s/}$//')

      echo "Electron options to inject: $ELECTRON_OPTIONS"

      # Find and replace the experimentalDarkMode entry to inject our options
      sed -i "s/experimentalDarkMode:!0/experimentalDarkMode:!0,$ELECTRON_OPTIONS/g" "$MAIN_JS"

      # Verify the change was made
      if grep -q "$ELECTRON_OPTIONS" "$MAIN_JS"; then
        echo "Successfully injected electron options"
      else
        echo "Warning: Failed to inject electron options"
      fi
    ''}

    ${optionalString (cfg.electron.backgroundColor or null != null) ''
      echo "Applying background color..."
      sed -i 's/setBackgroundColor([^)]*)/setBackgroundColor("${cfg.electron.backgroundColor}")/g' "$MAIN_JS"
    ''}

    # Find the workbench HTML file for CSS/JS injection
    WORKBENCH_HTML=""

    # Try different possible locations for the workbench HTML file in Cursor
    for possible_path in \
      "$out/share/cursor/resources/app/out/vs/code/electron-sandbox/workbench/workbench.html" \
      "$out/share/cursor/resources/app/out/vs/code/electron-sandbox/workbench/workbench.esm.html" \
      "$out/share/cursor/resources/app/out/vs/code/electron-sandbox/workbench/workbench-apc-extension.html" \
      "$out/lib/cursor/resources/app/out/vs/code/electron-sandbox/workbench/workbench.html" \
      "$out/lib/cursor/resources/app/out/vs/code/electron-sandbox/workbench/workbench.esm.html"
    do
      if [ -f "$possible_path" ]; then
        WORKBENCH_HTML="$possible_path"
        break
      fi
    done

    if [ -z "$WORKBENCH_HTML" ]; then
      echo "Warning: Could not find workbench HTML file in Cursor installation"
      echo "Available workbench files:"
      find $out -name "workbench*.html" -type f || echo "No workbench HTML files found"
      echo "Skipping CSS/JS injection..."
    else
      echo "Found workbench HTML at: $WORKBENCH_HTML"

      # Create backup of workbench HTML
      cp "$WORKBENCH_HTML" "$WORKBENCH_HTML.original"

      ${
        optionalString (cfg.customCSS.imports != [ ]) ''
                    echo "Processing custom CSS/JS imports for Cursor..."

                    # Generate the injection content
                    INJECTION_CONTENT=""

                    ${
                      lib.concatMapStrings (file:
                        let
                          filePath = if builtins.isString file then
                            file
                          else if builtins.isPath file then
                            toString file
                          else
                            throw "Import must be a string path or path type";
                          ext = let
                            parts = lib.splitString "." (baseNameOf filePath);
                          in if length parts > 1 then
                            ".${lib.last parts}"
                          else
                            "";
                        in if ext == ".css" then ''
                          echo "Adding CSS file: ${filePath}"
                          INJECTION_CONTENT="$INJECTION_CONTENT<style>$(cat ${filePath})</style>"
                        '' else if ext == ".js" then ''
                          echo "Adding JS file: ${filePath}"
                          INJECTION_CONTENT="$INJECTION_CONTENT<script>$(cat ${filePath})</script>"
                        '' else ''
                          echo "Warning: Unsupported file extension for ${filePath}, skipping"
                        '') cfg.customCSS.imports
                    }

                    ${
                      optionalString cfg.customCSS.statusBar ''
                        echo "Adding status bar indicator..."
                        INJECTION_CONTENT="$INJECTION_CONTENT<script>${cursorStatusBarJs}</script>"
                      ''
                    }

                    # Remove Content Security Policy meta tag to allow custom scripts
                    sed -i '/<meta.*http-equiv="Content-Security-Policy".*\/>/d' "$WORKBENCH_HTML"

                    # Inject our custom content before the closing </html> tag
                    # Add session ID and markers similar to the original extension
                    SESSION_ID="nixos-cursor-$(date +%s)"

                    sed -i "s|</html>|<!-- !! CURSOR-CUSTOM-CSS-SESSION-ID $SESSION_ID !! -->
          <!-- !! CURSOR-CUSTOM-CSS-START !! -->
          $INJECTION_CONTENT
          <!-- !! CURSOR-CUSTOM-CSS-END !! -->
          </html>|" "$WORKBENCH_HTML"

                    echo "Successfully injected custom CSS/JS into Cursor workbench"
        ''
      }

      ${
        optionalString (cfg.customCSS.imports == [ ]) ''
          echo "No custom CSS/JS imports configured for Cursor"
        ''
      }
    fi

    echo "Cursor UI modifications completed"
  '';

  # Create management scripts
  cursorUIScripts = pkgs.writeShellScriptBin "cursor-ui-info" ''
    echo "Cursor UI Style Module Information:"
    echo "=================================="
    echo "Electron options: ${builtins.toJSON cfg.electron}"
    echo "Auto-apply: ${if cfg.autoApply then "enabled" else "disabled"}"
    echo ""
    echo "Cursor Custom CSS/JS:"
    echo "Imports: ${toString cfg.customCSS.imports}"
    echo "Status bar indicator: ${
      if cfg.customCSS.statusBar then "enabled" else "disabled"
    }"
    echo ""
    echo "This module creates a modified Cursor package with your customizations."
    echo "The modifications are applied at build time, so they're persistent across reboots."
    echo ""
    echo "To see the differences, compare:"
    echo "  Original Cursor: ${cursorPkg}/share/cursor/resources/app/out/vs/code/electron-main/main.js"
    echo "  Modified Cursor: ${modifiedCursor}/share/cursor/resources/app/out/vs/code/electron-main/main.js"
    echo "  Original Workbench: ${cursorPkg}/share/cursor/resources/app/out/vs/code/electron-sandbox/workbench/"
    echo "  Modified Workbench: ${modifiedCursor}/share/cursor/resources/app/out/vs/code/electron-sandbox/workbench/"
  '';

in {
  options.programs.cursor-ui-style = {
    enable = mkEnableOption "Custom UI styling for Cursor editor";

    electron = mkOption {
      type = types.attrs;
      default = { };
      description = ''
        Electron BrowserWindow options to apply to Cursor.
        See https://www.electronjs.org/docs/latest/api/browser-window for available options.

        Common options:
        - frame: false (removes window frame)
        - titleBarStyle: "hiddenInset" (hides title bar but keeps controls)
        - backgroundColor: "#1e1e1e" (sets window background color)
        - roundedCorners: false (disables rounded corners on macOS)
        - transparent: true (makes window transparent)
        - opacity: 0.95 (sets window opacity)
      '';
      example = {
        frame = false;
        titleBarStyle = "hiddenInset";
        backgroundColor = "#1e1e1e";
        roundedCorners = false;
      };
    };

    customCSS = mkOption {
      type = types.submodule {
        options = {
          imports = mkOption {
            type = types.listOf (types.oneOf [ types.str types.path ]);
            default = [ ];
            description = ''
              List of CSS and JS files to inject into Cursor.
              Files can be specified as strings (file paths) or path types.
              Only .css and .js files are supported.

              Example:
              - ./my-custom-styles.css
              - /absolute/path/to/script.js
              - pkgs.writeText "my-styles.css" "body { background: red; }"
            '';
            example = [ ./custom-cursor-styles.css ./custom-cursor-script.js ];
          };

          statusBar = mkOption {
            type = types.bool;
            default = true;
            description = ''
              Whether to show a status bar indicator that custom CSS/JS is active.
              This adds a paint can icon to the status bar similar to the vscode-custom-css extension.
            '';
          };
        };
      };
      default = {
        imports = [ ];
        statusBar = true;
      };
      description = ''
        Cursor custom CSS and JS configuration.
        This replicates the functionality of the vscode-custom-css extension but for Cursor.
      '';
    };

    autoApply = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Whether to automatically use the modified cursor package.
        If false, the original cursor package will be used.
      '';
    };
  };

  config = mkIf cfg.enable {
    # Use the modified cursor package if autoApply is enabled and we have customizations
    environment.systemPackages = [
      (if cfg.autoApply
      && (cfg.electron != { } || cfg.customCSS.imports != [ ]) then
        modifiedCursor
      else
        cursorPkg)
      cursorUIScripts
    ];

    # Add some helpful information
    warnings = (mkIf (cfg.enable && cfg.electron != { }) [''
      cursor-ui-style: Applied electron options: ${builtins.toJSON cfg.electron}

      Note: Changes require a complete restart of Cursor to take effect.
      Run 'cursor-ui-info' for more details about the modifications.
    '']) ++ (mkIf (cfg.enable && cfg.customCSS.imports != [ ]) [''
      cursor-ui-style: Injected ${
        toString (length cfg.customCSS.imports)
      } custom CSS/JS file(s) into Cursor

      Files: ${lib.concatStringsSep ", " (map toString cfg.customCSS.imports)}
      Status bar indicator: ${
        if cfg.customCSS.statusBar then "enabled" else "disabled"
      }

      Note: Changes require a complete restart of Cursor to take effect.
      Run 'cursor-ui-info' for more details about the modifications.
    '']);

    # Add assertion to ensure we have valid configuration
    assertions = [
      {
        assertion = cfg.enable
          -> (cfg.electron == { } || builtins.isAttrs cfg.electron);
        message = "cursor-ui-style.electron must be an attribute set";
      }
      {
        assertion = cfg.enable -> (cfg.customCSS.imports == [ ]
          || builtins.isList cfg.customCSS.imports);
        message = "cursor-ui-style.customCSS.imports must be a list";
      }
      {
        assertion = cfg.enable -> builtins.all (file:
          let
            filePath = if builtins.isString file then
              file
            else if builtins.isPath file then
              toString file
            else
              false;
            ext = if filePath != false then
              let parts = lib.splitString "." (baseNameOf filePath);
              in if length parts > 1 then ".${lib.last parts}" else ""
            else
              "";
          in filePath != false && (ext == ".css" || ext == ".js" || ext == ""))
          cfg.customCSS.imports;
        message =
          "cursor-ui-style.customCSS.imports must contain only .css and .js files";
      }
    ];
  };
}
