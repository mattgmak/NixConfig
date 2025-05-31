{ config, lib, pkgs, pkgs-for-cursor ? pkgs, ... }:

with lib;

let
  cfg = config.programs.cursor-ui-style;

  # Use pkgs-for-cursor if available, otherwise fall back to pkgs
  cursorPkg = if pkgs-for-cursor ? code-cursor then
    pkgs-for-cursor.code-cursor
  else
    pkgs.code-cursor;

  # Create a modified cursor package with UI customizations
  modifiedCursor =
    pkgs.runCommand "cursor-ui-styled" { buildInputs = [ pkgs.jq ]; } ''
      # Create output directory
      mkdir -p $out

      # Copy the original cursor
      cp -r ${cursorPkg}/* $out/
      chmod -R +w $out/

      # Find the main.js file
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

      # Create backup
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

      echo "Cursor UI modifications completed"
    '';

  # Create management scripts
  cursorUIScripts = pkgs.writeShellScriptBin "cursor-ui-info" ''
    echo "Cursor UI Style Module Information:"
    echo "=================================="
    echo "Electron options: ${builtins.toJSON cfg.electron}"
    echo "Auto-apply: ${if cfg.autoApply then "enabled" else "disabled"}"
    echo ""
    echo "This module creates a modified cursor package with your UI customizations."
    echo "The modifications are applied at build time, so they're persistent across reboots."
    echo ""
    echo "To see the differences, compare:"
    echo "  Original: ${cursorPkg}/share/cursor/resources/app/out/vs/code/electron-main/main.js"
    echo "  Modified: ${modifiedCursor}/share/cursor/resources/app/out/vs/code/electron-main/main.js"
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
    # Use the modified cursor package if autoApply is enabled and we have electron options
    environment.systemPackages = [
      (if cfg.autoApply && cfg.electron != { } then
        modifiedCursor
      else
        cursorPkg)
      cursorUIScripts
    ];

    # Add some helpful information
    warnings = mkIf (cfg.enable && cfg.electron != { }) [''
      cursor-ui-style: Applied electron options: ${builtins.toJSON cfg.electron}

      Note: Changes require a complete restart of Cursor to take effect.
      Run 'cursor-ui-info' for more details about the modifications.
    ''];

    # Add assertion to ensure we have valid electron options
    assertions = [{
      assertion = cfg.enable
        -> (cfg.electron == { } || builtins.isAttrs cfg.electron);
      message = "cursor-ui-style.electron must be an attribute set";
    }];
  };
}
