{ config, lib, pkgs-for-cursor ? pkgs, pkgs, ... }:

with lib;

let
  cfg = config.programs.cursor-injection;

  # Create an overlay that modifies the code-cursor package
  cursorInjectionOverlay = final: prev: {
    code-cursor = let
      originalCursor = prev.code-cursor;

      # Convert electron options to JSON string (keeping full JSON object syntax)
      electronOptionsStr =
        if cfg.electron != { } then builtins.toJSON cfg.electron else "{}";

      # Create script to inject into main process
      mainInjectionScript = ''
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
        echo "Injecting cursor customizations..."

        # Get the extracted directory name
        ${optionalString pkgs.stdenv.isLinux ''
          extracted_dir=$(find . -maxdepth 1 -name "*extracted" -type d | head -1)''}
        ${optionalString pkgs.stdenv.isDarwin
        "extracted_dir=./Cursor.app/Contents"}
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
          echo "Injecting cursor customizations into main.js..."
          {
            cat "$mainjs_file"
            echo ""
            echo '${mainInjectionScript}'
          } > "$mainjs_file.tmp"
          mv "$mainjs_file.tmp" "$mainjs_file"
          echo "Successfully injected customizations into main.js"
        fi

        # Also try to find and modify any workbench.html files in extracted directory
        find "$extracted_dir" -name "workbench.html" -type f | while read -r htmlfile; do
          echo "Found workbench.html: $htmlfile"
          ${
            optionalString (cfg.customCSSFileStubs != [ ]) ''
              # Inject custom CSS file stubs into HTML
              ${concatMapStringsSep "\n" (fileName: ''
                echo "Injecting CSS file: ${fileName}"
                # Use printf to handle multiline content properly
                printf '%s\n' "$(cat <<'EOF'
                s|</head>| <!-- Custom CSS ${fileName} -->\n<link rel="stylesheet" href="vscode-file://vscode-app${config.home.homeDirectory}/.cursor/extensions/custom/${fileName}">\n</head>|
                EOF
                )" | sed -i -f - "$htmlfile"
              '') cfg.customCSSFileStubs}
            ''
          }
          ${
            optionalString (cfg.customJSFileStubs != [ ]) ''
              # Inject custom JS file stubs into HTML
              ${concatMapStringsSep "\n" (fileName: ''
                echo "Injecting JS file: ${fileName}"
                printf '%s\n' "$(cat <<'EOF'
                s|</head>| <!-- Custom JS ${fileName} -->\n<script type="text/javascript" src="vscode-file://vscode-app${config.home.homeDirectory}/.cursor/extensions/custom/${fileName}"></script>\n</head>|
                EOF
                )" | sed -i -f - "$htmlfile"
              '') cfg.customJSFileStubs}
            ''
          }
        done

        echo "Cursor injection complete on extracted directory."
      '';
    });
  };

  extendedCursor = (pkgs-for-cursor.extend cursorInjectionOverlay).code-cursor;

in {
  options.programs.cursor-injection = {
    enable = mkEnableOption "Cursor injection";

    electron = mkOption {
      type = types.attrs;
      default = { };
      description = "Electron BrowserWindow options to apply";
      example = {
        frame = false;
        titleBarStyle = "hiddenInset";
      };
    };

    customCSSFileStubs = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description =
        "List of file stubs names to be injected into Cursor which will be loaded as CSS from the cursor extensions directory";
      example = [ "vscode.css" ];
    };

    customJSFileStubs = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description =
        "List of file stubs names to be injected into Cursor which will be loaded as JS from the cursor extensions directory";
      example = [ "vscode.js" ];
    };
  };

  config = mkIf cfg.enable {
    warnings = [
      (mkIf (cfg.electron != { }) ''
        cursor-injection:
        Applied electron options via overlay to extracted contents: ${
          builtins.toJSON cfg.electron
        }
      '')

      (mkIf (cfg.customCSSFileStubs != [ ] || cfg.customJSFileStubs != [ ]) ''
        cursor-injection:
        Injected custom CSS/JS into extracted Cursor contents via overlay
        - Custom CSS: ${concatStringsSep ", " cfg.customCSSFileStubs}
        - Custom JS: ${concatStringsSep ", " cfg.customJSFileStubs}
      '')
    ];

    # Apply the overlay to the pinned pkgs-for-cursor instance and use the modified package
    stylix.targets.vscode.enable = false;
    programs.vscode.package = lib.mkForce extendedCursor;
  };
}
