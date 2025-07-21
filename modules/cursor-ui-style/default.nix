{ config, lib, pkgs, pkgs-for-cursor ? pkgs, ... }:

with lib;

let
  cfg = config.programs.cursor-ui-style;

  # Create an overlay that modifies the code-cursor package
  cursorUIOverlay = final: prev: {
    code-cursor = let
      originalCursor = if pkgs-for-cursor ? code-cursor then
        pkgs-for-cursor.code-cursor
      else
        prev.code-cursor;

      # Convert electron options to JSON string (removing outer braces for injection)
      electronOptionsStr = if cfg.electron != { } then
        let
          electronJson = builtins.toJSON cfg.electron;
          # Remove the outer braces to get just the key-value pairs
          innerJson =
            builtins.substring 1 (builtins.stringLength electronJson - 2)
            electronJson;
        in innerJson
      else
        "";

      # Create script to inject into main process
      injectionScript = ''
        // Cursor UI Style - Electron Options
        const { app } = require('electron');
        ${optionalString (electronOptionsStr != "")
        "Object.assign(process.env, { ELECTRON_OPTIONS: '${electronOptionsStr}' });"}

        // Load custom CSS/JS files
        ${concatMapStringsSep "\n" (file: ''
          try {
            const customPath = '${file}';
            if (require('fs').existsSync(customPath)) {
              if (customPath.endsWith('.css')) {
                const css = require('fs').readFileSync(customPath, 'utf8');
                app.whenReady().then(() => {
                  const { session } = require('electron');
                  session.defaultSession.webContents.on('dom-ready', () => {
                    session.defaultSession.webContents.insertCSS(css);
                  });
                });
              } else if (customPath.endsWith('.js')) {
                require(customPath);
              }
            }
          } catch (e) {
            console.error('Cursor UI Style injection error:', e);
          }
        '') cfg.customFiles}
      '';

      # Override the entire appimageTools.wrapType2 call
    in pkgs.appimageTools.wrapType2 {
      inherit (originalCursor) version src;
      pname = "${originalCursor.pname or "code-cursor"}-ui-styled";

      # Use the postExtract hook to modify the extracted contents
      postExtract = ''
        echo "Applying Cursor UI customizations to extracted contents..."

        # Find the main.js file in the extracted AppImage
        mainjs_file=""
        for candidate in "$extracted/usr/share/cursor/resources/app/out/main.js" \
                         "$extracted/resources/app/out/main.js" \
                         "$extracted/opt/Cursor/resources/app/out/main.js"; do
          if [[ -f "$candidate" ]]; then
            mainjs_file="$candidate"
            echo "Found main.js at: $mainjs_file"
            break
          fi
        done

        if [[ -z "$mainjs_file" ]]; then
          echo "Warning: Could not find main.js file in extracted AppImage"
          find "$extracted" -name "main.js" -type f | head -5
        else
          # Inject our customizations at the beginning of main.js
          echo "Injecting cursor UI customizations..."
          {
            echo '${injectionScript}'
            echo ""
            cat "$mainjs_file"
          } > "$mainjs_file.tmp"
          mv "$mainjs_file.tmp" "$mainjs_file"
          echo "Successfully injected customizations into main.js"
        fi

        # Also try to find and modify any workbench.html files
        find "$extracted" -name "workbench.html" -type f | while read -r htmlfile; do
          echo "Found workbench.html: $htmlfile"
          ${
            optionalString (cfg.customFiles != [ ]) ''
              # Inject custom CSS/JS files into HTML
              ${concatMapStringsSep "\n" (file: ''
                if [[ "${file}" == *.css ]]; then
                  echo "Injecting CSS file: ${file}"
                  sed -i 's|</head>|<style>/*Custom Cursor UI Style*/ @import url("file://${file}");</style></head>|' "$htmlfile"
                elif [[ "${file}" == *.js ]]; then
                  echo "Injecting JS file: ${file}"
                  sed -i 's|</head>|<script src="file://${file}"></script></head>|' "$htmlfile"
                fi
              '') cfg.customFiles}
            ''
          }
        done

        echo "Cursor UI customization complete."
      '';
    };
  };

in {
  options.programs.cursor-ui-style = {
    enable = mkEnableOption "Cursor UI style customizations";

    autoApply = mkOption {
      type = types.bool;
      default = false;
      description = "Automatically apply the overlay to the system packages";
    };

    electron = mkOption {
      type = types.attrs;
      default = { };
      description = "Electron BrowserWindow options to apply";
      example = {
        frame = false;
        titleBarStyle = "hiddenInset";
      };
    };

    customFiles = mkOption {
      type = types.listOf types.path;
      default = [ ];
      description = "List of CSS/JS files to inject into Cursor";
    };

    statusBarIndicator = mkOption {
      type = types.bool;
      default = true;
      description = "Show status bar indicator when customizations are active";
    };
  };

  config = mkIf cfg.enable {
    warnings = [
      (mkIf (cfg.electron != { }) ''
        cursor-ui-style: Applied electron options via overlay to extracted contents: ${
          builtins.toJSON cfg.electron
        }

                              Note: Changes require a complete restart of Cursor to take effect.
                              The overlay modifies the extracted AppImage contents from pkgs-for-cursor.
                              Run 'cursor-ui-info' for more details about the modifications.'')

      (mkIf (cfg.customFiles != [ ]) ''
        cursor-ui-style: Injected ${
          toString (length cfg.customFiles)
        } custom CSS/JS file(s) into extracted Cursor contents via overlay

                              Files: ${
                                concatStringsSep ", "
                                (map toString cfg.customFiles)
                              }
                              Status bar indicator: ${
                                if cfg.statusBarIndicator then
                                  "enabled"
                                else
                                  "disabled"
                              }

                              Note: Changes require a complete restart of Cursor to take effect.
                              The overlay modifies the extracted AppImage contents from pkgs-for-cursor.
                              Run 'cursor-ui-info' for more details about the modifications.'')
    ];

    nixpkgs.overlays = mkIf cfg.autoApply [ cursorUIOverlay ];

    environment.systemPackages = mkIf cfg.autoApply [
      (pkgs.writeShellScriptBin "cursor-ui-info" ''
        echo "Cursor UI Style Information:"
        echo "  Status: ${if cfg.enable then "Enabled" else "Disabled"}"
        echo "  Electron Options: ${builtins.toJSON cfg.electron}"
        echo "  Custom Files: ${toString (length cfg.customFiles)}"
        ${optionalString (cfg.customFiles != [ ]) ''
          echo "  Files: ${
            concatStringsSep ", " (map toString cfg.customFiles)
          }"''}
        echo "  Auto-apply overlay: ${if cfg.autoApply then "Yes" else "No"}"
        echo ""
        echo "Current Cursor package: $((nix eval --raw '.#nixosConfigurations.${config.networking.hostName}.pkgs.code-cursor.pname' 2>/dev/null) || echo 'Not available')"
        echo ""
        echo "To apply changes:"
        echo "  1. Rebuild your system: sudo nixos-rebuild switch"
        echo "  2. Completely restart Cursor (close all windows/processes)"
        echo ""
        echo "To verify modifications are applied:"
        echo "  1. Open Cursor"
        echo "  2. Check if electron options are reflected (frameless window, etc.)"
        echo "  3. Open Developer Tools to see if custom CSS/JS is loaded"
      '')
    ];
  };
}
