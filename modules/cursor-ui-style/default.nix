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

      # Convert electron options to JSON string (keeping full JSON object syntax)
      electronOptionsStr =
        if cfg.electron != { } then builtins.toJSON cfg.electron else "{}";

      # Create script to inject into main process
      injectionScript = ''
        // Cursor UI Style - Electron Options
        import { app, BrowserWindow } from "electron";

        ${if cfg.electron != { } then ''
          // Apply electron options by intercepting BrowserWindow creation
          const electronOptions = ${electronOptionsStr};
          console.log("Cursor UI Style: Applying electron options:", electronOptions);

          // Store the original BrowserWindow constructor
          const OriginalBrowserWindow = BrowserWindow;

          // Override BrowserWindow to apply our options
          function PatchedBrowserWindow(options = {}) {
            // Merge our electron options with the existing options
            const mergedOptions = { ...options, ...electronOptions };
            console.log("Cursor UI Style: Creating BrowserWindow with options:", mergedOptions);
            return new OriginalBrowserWindow(mergedOptions);
          }

          // Replace the original BrowserWindow
          global.BrowserWindow = PatchedBrowserWindow;
          // module.exports.BrowserWindow = PatchedBrowserWindow;
          export { PatchedBrowserWindow as BrowserWindow };
        '' else
          ""}
      '';

      # Override the original cursor package instead of replacing it entirely
    in originalCursor.overrideAttrs (oldAttrs: {
      # Override postUnpack to modify extracted content directly
      postUnpack = (oldAttrs.postUnpack or "") + ''
        echo "Applying Cursor UI customizations..."

        # Get the extracted directory name
        extracted_dir=$(find . -maxdepth 1 -name "*extracted" -type d | head -1)
        if [[ -z "$extracted_dir" ]]; then
          echo "Error: Could not find extracted directory"
          exit 1
        fi

        echo "Working on extracted directory: $extracted_dir"

        # Find the main.js file in the extracted directory
        mainjs_file=""
        for candidate in "$extracted_dir/usr/share/cursor/resources/app/out/main.js" \
                         "$extracted_dir/resources/app/out/main.js" \
                         "$extracted_dir/opt/Cursor/resources/app/out/main.js"; do
          if [[ -f "$candidate" ]]; then
            mainjs_file="$candidate"
            echo "Found main.js at: $mainjs_file"
            break
          fi
        done

        if [[ -z "$mainjs_file" ]]; then
          echo "Warning: Could not find main.js file in extracted directory"
          find "$extracted_dir" -name "main.js" -type f | head -5
        else
          # Inject our customizations at the beginning of main.js
          echo "Injecting cursor UI customizations into main.js..."
          {
            cat "$mainjs_file"
            echo ""
            echo '${injectionScript}'
          } > "$mainjs_file.tmp"
          mv "$mainjs_file.tmp" "$mainjs_file"
          echo "Successfully injected customizations into main.js"
        fi

        # Also try to find and modify any workbench.html files in extracted directory
        find "$extracted_dir" -name "workbench.html" -type f | while read -r htmlfile; do
          echo "Found workbench.html: $htmlfile"
          ${
            optionalString (cfg.customFiles != [ ]) ''
              # Inject custom CSS/JS files into HTML
              ${concatMapStringsSep "\n" (file:
                let
                  fileContent = builtins.readFile file;
                  # Escape special characters for shell
                  escapedContent =
                    builtins.replaceStrings [ "\n" "\r" "\\" "'" ''"'' "$" ] [
                      "\\n"
                      "\\r"
                      "\\\\"
                      "\\'"
                      ''\"''
                      "\\$"
                    ] fileContent;
                in ''
                                    if [[ "${file}" == *.css ]]; then
                                      echo "Injecting CSS file: ${file}"
                                      # Use printf to handle multiline content properly
                                      printf '%s\n' "$(cat <<'EOF'
                  s|</head>|<style>/*Custom Cursor UI Style ${file}*/ ${escapedContent}</style></head>|
                  EOF
                  )" | sed -i -f - "$htmlfile"
                                    elif [[ "${file}" == *.js ]]; then
                                      echo "Injecting JS file: ${file}"
                                      printf '%s\n' "$(cat <<'EOF'
                  s|</head>|<script>/*Custom Cursor UI Style ${file}*/ ${escapedContent}</script></head>|
                  EOF
                  )" | sed -i -f - "$htmlfile"
                                    fi
                '') cfg.customFiles}
            ''
          }
        done

        echo "Cursor UI customization complete on extracted directory."
      '';

      # Keep the original sourceRoot since we're modifying in place
      # sourceRoot remains: ${oldAttrs.pname}-${oldAttrs.version}-extracted/usr/share/cursor
    });
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
  };
}
