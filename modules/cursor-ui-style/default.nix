{ config, lib, pkgs, pkgs-for-cursor ? pkgs, ... }:

with lib;

let
  cfg = config.programs.cursor-ui-style;

  # Use pkgs-for-cursor if available, otherwise fall back to pkgs
  cursorPkg = if pkgs-for-cursor ? code-cursor then
    pkgs-for-cursor.code-cursor
  else
    pkgs.code-cursor;

  # Convert electron options to JSON string (removing outer braces for injection)
  electronOptionsStr = if cfg.electron != { } then
    let
      electronJson = builtins.toJSON cfg.electron;
      # Remove the outer braces to get just the key-value pairs
      innerJson = builtins.substring 1 (builtins.stringLength electronJson - 2)
        electronJson;
      # Escape quotes for shell usage in sed commands
      escapedJson = lib.replaceStrings [ ''"'' ] [ ''\"'' ] innerJson;
    in escapedJson
  else
    "";

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
    # Inherit version and other metadata from the original cursor package
    inherit (cursorPkg) version;
    meta = cursorPkg.meta or { };
    passthru = cursorPkg.passthru or { };
  } ''
        # Create the build script content as a variable
        BUILD_SCRIPT=$(cat << 'BUILD_SCRIPT_EOF'
    #!/bin/bash
    set -e

    # Create output directory
    mkdir -p $out

    # Copy the original cursor package
    cp -r ${cursorPkg}/* $out/
    chmod -R u+w $out/

    # Find the main.js file for electron options injection
    MAIN_JS=""

    # Try different possible locations for main.js in Cursor
    for possible_path in \
      "$out/share/cursor/resources/app/out/main.js" \
      "$out/usr/share/cursor/resources/app/out/vs/code/electron-main/main.js" \
      "$out/share/cursor/resources/app/out/vs/code/electron-main/main.js" \
      "$out/lib/cursor/resources/app/out/vs/code/electron-main/main.js"
    do
      if [ -f "$possible_path" ]; then
        MAIN_JS="$possible_path"
        break
      fi
    done

    if [ -z "$MAIN_JS" ]; then
      echo "Error: Could not find main.js file in Cursor installation"
      echo "Available files in app/out:"
      find $out -name "*.js" -path "*/app/out/*" | head -10
      exit 1
    fi

    echo "Found main.js at: $MAIN_JS"

    ${optionalString (cfg.electron != { }) ''
      echo "Applying electron window options..."
      echo "Electron options to inject: ${electronOptionsStr}"

      # Find and replace the experimentalDarkMode entry to inject our options
      sed -i "s/experimentalDarkMode:!0/experimentalDarkMode:!0,${electronOptionsStr}/g" "$MAIN_JS"

      # Verify the change was made
      if grep -q "${electronOptionsStr}" "$MAIN_JS"; then
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
      "$out/usr/share/cursor/resources/app/out/vs/code/electron-sandbox/workbench/workbench.html" \
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

      ${
        optionalString (cfg.customCSS.imports != [ ]) ''
                                      echo "Processing custom CSS/JS imports for Cursor..."

                                      # Generate the injection content
                                      INJECTION_CONTENT=""

                                      ${
                                        lib.concatStringsSep "\n" (map (file:
                                          let
                                            filePath =
                                              if builtins.isPath file then
                                                toString file
                                              else
                                                throw
                                                "Import must be a path type";
                                            ext = let
                                              parts = lib.splitString "."
                                                (baseNameOf filePath);
                                            in if length parts > 1 then
                                              ".${lib.last parts}"
                                            else
                                              "";
                                            # Read file content using Nix builtins instead of cat
                                            fileContent =
                                              if builtins.isPath file then
                                                builtins.readFile file
                                              else
                                                throw
                                                "Import must be a path type";
                                            # Use base64 encoding to safely handle content with special characters
                                            base64Content = builtins.readFile
                                              (pkgs.runCommand
                                                "base64-${baseNameOf filePath}"
                                                { } ''
                                                  echo -n ${
                                                    lib.escapeShellArg
                                                    fileContent
                                                  } | base64 -w 0 > $out
                                                '');
                                          in if ext == ".css" then ''
                                            echo "Adding CSS file: ${filePath}"
                                            DECODED_CONTENT=$(echo "${base64Content}" | base64 -d)
                                            INJECTION_CONTENT="$INJECTION_CONTENT<style>$DECODED_CONTENT</style>"'' else if ext
                                          == ".js" then ''
                                            echo "Adding JS file: ${filePath}"
                                            DECODED_CONTENT=$(echo "${base64Content}" | base64 -d)
                                            INJECTION_CONTENT="$INJECTION_CONTENT<script>$DECODED_CONTENT</script>"'' else
                                            ''
                                              echo "Warning: Unsupported file extension for ${filePath}, skipping"'')
                                          cfg.customCSS.imports)
                                      }

                                      ${
                                        optionalString
                                        cfg.customCSS.statusBar ''
                                          echo "Adding status bar indicator..."
                                          # Use base64 encoding to safely handle JavaScript content
                                          JS_BASE64="${
                                            builtins.readFile (pkgs.runCommand
                                              "base64-statusbar-js" { } ''
                                                echo -n ${
                                                  lib.escapeShellArg
                                                  cursorStatusBarJs
                                                } | base64 -w 0 > $out
                                              '')
                                          }"
                                          DECODED_JS=$(echo "$JS_BASE64" | base64 -d)
                                          INJECTION_CONTENT="$INJECTION_CONTENT<script>$DECODED_JS</script>"
                                        ''
                                      }

                                      # Remove Content Security Policy meta tag to allow custom scripts
                                      sed -i '/<meta.*http-equiv="Content-Security-Policy".*\/>/d' "$WORKBENCH_HTML"

                                      # Inject our custom content before the closing </html> tag
                                      # Add session ID and markers similar to the original extension
                                      SESSION_ID="nixos-cursor-$(date +%s)"

                                      # Replace the closing </html> tag with our injection content
                                      sed -i 's|</html>||g' "$WORKBENCH_HTML"

                                      # Append the injection content directly
                                      cat >> "$WORKBENCH_HTML" << INJECTION_EOF

          <!-- !! CURSOR-CUSTOM-CSS-SESSION-ID $SESSION_ID !! -->
          <!-- !! CURSOR-CUSTOM-CSS-START !! -->
          $INJECTION_CONTENT
          <!-- !! CURSOR-CUSTOM-CSS-END !! -->
          </html>
          INJECTION_EOF

                                      echo "Successfully injected custom CSS/JS into Cursor workbench"
        ''
      }

      ${
        optionalString (cfg.customCSS.imports == [ ]) ''
          echo "No custom CSS/JS imports configured for Cursor"
        ''
      }
    fi

    # Recursively fix all references to the original cursor package
    echo "Recursively replacing all references to original cursor package..."
    echo "Original package path: ${cursorPkg}"
    echo "Modified package path: $out"

    # Function to process a file or symlink
    process_file() {
      local file_path="$1"
      local relative_path="''${file_path#$out/}"

      if [ -L "$file_path" ]; then
        # Handle symlinks: convert to regular file if it points to original package
        local link_target=$(readlink "$file_path")
        if [[ "$link_target" == *"${cursorPkg}"* ]]; then
          echo "Converting symlink to regular file: $relative_path"
          # Remove the symlink
          rm "$file_path"
          # Copy the target file
          cp -L "${cursorPkg}/$relative_path" "$file_path" 2>/dev/null || {
            echo "Warning: Could not copy target for symlink $relative_path"
            return
          }
          # Make it writable
          chmod u+w "$file_path"
        fi
      fi

      # Process regular files (including converted symlinks)
      if [ -f "$file_path" ] && [ ! -L "$file_path" ]; then
        # Check if file contains references to original package
        if grep -q "${cursorPkg}" "$file_path" 2>/dev/null; then
          echo "Updating references in: $relative_path"
          # Replace all references
          sed -i "s|${cursorPkg}|$out|g" "$file_path" 2>/dev/null || {
            echo "Warning: Could not update references in $relative_path"
          }
        fi
      fi
    }

    # Export the function so it can be used with find -exec
    export -f process_file
    export out

    # Process all files and symlinks recursively
    echo "Scanning for files and symlinks to process..."
    find "$out" -type f -o -type l | while read -r file_path; do
      process_file "$file_path"
    done

    # Special handling for common wrapper scripts and executables
    echo "Applying special fixes for common wrapper locations..."

    # Fix any shell scripts that might contain package references
    find "$out" -type f \( -name "*.sh" -o -name "cursor*" -o -name "*.wrapper" \) | while read -r script_file; do
      if [ -f "$script_file" ] && grep -q "${cursorPkg}" "$script_file" 2>/dev/null; then
        echo "Fixing script: ''${script_file#$out/}"
        sed -i "s|${cursorPkg}|$out|g" "$script_file"
      fi
    done

    # Fix desktop files and other configuration files
    find "$out" -type f \( -name "*.desktop" -o -name "*.conf" -o -name "*.json" -o -name "*.xml" \) | while read -r config_file; do
      if [ -f "$config_file" ] && grep -q "${cursorPkg}" "$config_file" 2>/dev/null; then
        echo "Fixing config file: ''${config_file#$out/}"
        sed -i "s|${cursorPkg}|$out|g" "$config_file"
      fi
    done

    echo "Completed recursive package reference replacement"

    # Special handling for wrapped binaries
    echo "Fixing wrapped binaries..."
    find "$out" -type f -name "*-wrapped" -o -name ".*-wrapped" | while read -r wrapped_file; do
      if [ -f "$wrapped_file" ]; then
        echo "Processing wrapped binary: ''${wrapped_file#$out/}"

        # Check if it's a script or binary that contains package references
        if file "$wrapped_file" | grep -q "text\|script"; then
          # It's a text file/script
          if grep -q "${cursorPkg}" "$wrapped_file" 2>/dev/null; then
            echo "Updating references in wrapped script: ''${wrapped_file#$out/}"
            sed -i "s|${cursorPkg}|$out|g" "$wrapped_file"
          fi
        else
          # It's a binary - check if it's actually a symlink to the original package
          if [ -L "$wrapped_file" ]; then
            link_target=$(readlink "$wrapped_file")
            if [[ "$link_target" == *"${cursorPkg}"* ]]; then
              echo "Updating wrapped binary symlink: ''${wrapped_file#$out/}"
              rm "$wrapped_file"
              # Create new symlink pointing to our modified package
              new_target="''${link_target//${cursorPkg}/$out}"
              ln -s "$new_target" "$wrapped_file"
            fi
          fi
        fi
      fi
    done

    # Also check for any remaining symlinks that might point to the original package
    echo "Checking for remaining symlinks to original package..."
    find "$out" -type l | while read -r symlink_file; do
      link_target=$(readlink "$symlink_file")
      if [[ "$link_target" == *"${cursorPkg}"* ]]; then
        echo "Fixing remaining symlink: ''${symlink_file#$out/} -> $link_target"
        rm "$symlink_file"
        new_target="''${link_target//${cursorPkg}/$out}"
        ln -s "$new_target" "$symlink_file"
      fi
    done

    # Special handling for cursor-related symlinks that might point to wrapped versions
    echo "Checking for cursor-related symlinks (including wrapped versions)..."
    find "$out" -type l | while read -r symlink_file; do
      link_target=$(readlink "$symlink_file")
      # Check if the symlink points to any cursor-related package in the nix store
      if [[ "$link_target" == *"/nix/store/"*"cursor-"* ]]; then
        # Extract the cursor version from our package
        cursor_version=$(basename "${cursorPkg}" | sed 's/cursor-//' | sed 's/-.*$//')
        echo "Found cursor-related symlink: ''${symlink_file#$out/} -> $link_target"
        echo "Cursor version detected: $cursor_version"

        # Check if this symlink should point to our modified package instead
        relative_path="''${symlink_file#$out/}"
        if [ -f "$out/$relative_path" ] || [ -L "$out/$relative_path" ]; then
          # Try to find the equivalent file in our modified package
          potential_target=""

          # For .cursor-wrapped, try to find the actual cursor executable in our package
          if [[ "$relative_path" == *".cursor-wrapped"* ]]; then
            # Look for the main cursor executable in our package
            for possible_cursor in \
              "$out/share/cursor/cursor" \
              "$out/lib/cursor/cursor" \
              "$out/bin/cursor-unwrapped" \
              "$out/share/cursor/resources/app/cursor"
            do
              if [ -f "$possible_cursor" ]; then
                potential_target="$possible_cursor"
                break
              fi
            done

            if [ -n "$potential_target" ]; then
              echo "Redirecting wrapped cursor to modified package: $potential_target"
              rm "$symlink_file"
              ln -s "$potential_target" "$symlink_file"
            else
              echo "Warning: Could not find cursor executable in modified package for $relative_path"
            fi
          fi
        fi
      fi
    done

    # Handle external cursor-related symlinks by copying targets locally
    echo "Fixing external cursor-related symlinks..."
    find "$out" -type l | while read -r symlink_file; do
      link_target=$(readlink "$symlink_file")
      # Check if symlink points to external cursor packages
      if [[ "$link_target" == *"/nix/store/"*"cursor-"* ]] && [[ "$link_target" != "$out"* ]]; then
        echo "Found external cursor symlink: ''${symlink_file#$out/} -> $link_target"

        # Copy the target file into our package if it exists
        if [ -f "$link_target" ]; then
          # Create a local copy of the target
          local_target="$out/lib/cursor-wrapped-$(basename "$link_target")"
          mkdir -p "$(dirname "$local_target")"
          cp "$link_target" "$local_target"
          chmod +x "$local_target"

          # Update the symlink to point to our local copy
          rm "$symlink_file"
          ln -s "$local_target" "$symlink_file"

          echo "Copied external target and updated symlink: ''${symlink_file#$out/} -> $local_target"
        else
          echo "Warning: External target does not exist: $link_target"
        fi
      fi
    done

    # Rename the main cursor binary to cursor-styled
    echo "Renaming cursor executable to cursor-styled..."
    CURSOR_BIN=""
    for possible_bin in \
      "$out/bin/cursor" \
      "$out/usr/bin/cursor"
    do
      if [ -f "$possible_bin" ]; then
        CURSOR_BIN="$possible_bin"
        break
      fi
    done

    if [ -n "$CURSOR_BIN" ]; then
      CURSOR_STYLED="$(dirname "$CURSOR_BIN")/cursor-styled"
      mv "$CURSOR_BIN" "$CURSOR_STYLED"
      echo "✓ Renamed cursor binary: ''${CURSOR_BIN#$out/} -> ''${CURSOR_STYLED#$out/}"

      # Update any desktop files to reference cursor-styled
      find "$out" -name "*.desktop" -type f | while read -r desktop_file; do
        if grep -q "cursor" "$desktop_file"; then
          echo "Updating desktop file: ''${desktop_file#$out/}"
          sed -i "s|/cursor|/cursor-styled|g" "$desktop_file"
          sed -i "s|Exec=cursor|Exec=cursor-styled|g" "$desktop_file"
        fi
      done
    else
      echo "⚠ Warning: Could not find main cursor binary to rename"
    fi

    echo "Cursor UI modifications completed with cursor-styled executable"
    BUILD_SCRIPT_EOF
    )

        # Save the script for debugging and execute it with error handling
        echo "$BUILD_SCRIPT" > /tmp/cursor-ui-build-script.sh
        chmod +x /tmp/cursor-ui-build-script.sh

        echo "=== Executing Cursor UI build script ==="
        echo "Script saved to: /tmp/cursor-ui-build-script.sh"
        echo "Script size: $(echo "$BUILD_SCRIPT" | wc -c) bytes"
        echo "Script lines: $(echo "$BUILD_SCRIPT" | wc -l) lines"
        echo ""

        # Execute the script and capture any errors
        if ! bash /tmp/cursor-ui-build-script.sh; then
          echo ""
          echo "=== BUILD SCRIPT FAILED - DUMPING SCRIPT CONTENT FOR DEBUG ==="
          echo "=============================================================="
          echo "$BUILD_SCRIPT"
          echo "=============================================================="
          echo "=== END OF SCRIPT DUMP ==="
          echo ""
          echo "You can also find the script at: /tmp/cursor-ui-build-script.sh"
          echo "To debug: bash -n /tmp/cursor-ui-build-script.sh"
          exit 1
        fi
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
    echo "The modified version is available as 'cursor-styled' to run alongside the original."
    echo ""
    echo "To see the differences, compare:"
    echo "  Original Cursor: ${cursorPkg}/share/cursor/resources/app/out/main.js"
    echo "  Modified Cursor: ${modifiedCursor}/share/cursor/resources/app/out/main.js"
    echo "  Original Workbench: ${cursorPkg}/share/cursor/resources/app/out/vs/code/electron-sandbox/workbench/"
    echo "  Modified Workbench: ${modifiedCursor}/share/cursor/resources/app/out/vs/code/electron-sandbox/workbench/"
    echo ""
    echo "Run 'cursor-ui-diff' to see the actual file differences."
    echo "Run 'cursor-styled' to launch the modified version."
    echo "Run 'cursor' to launch the original version (if installed separately)."
  '';

  cursorUIDiffScript = pkgs.writeShellScriptBin "cursor-ui-diff" ''
    echo "Cursor UI Style File Differences:"
    echo "================================="
    echo ""

    # Check if modified cursor exists
    if [ ! -d "${modifiedCursor}" ]; then
      echo "Error: Modified cursor package not found at ${modifiedCursor}"
      echo "Make sure cursor-ui-style is enabled and the system has been rebuilt."
      exit 1
    fi

    # Find main.js files
    ORIGINAL_MAIN_JS=""
    MODIFIED_MAIN_JS=""

    # Try different possible locations for main.js
    for possible_path in \
      "share/cursor/resources/app/out/main.js" \
      "usr/share/cursor/resources/app/out/vs/code/electron-main/main.js" \
      "share/cursor/resources/app/out/vs/code/electron-main/main.js"
    do
      if [ -f "${cursorPkg}/$possible_path" ]; then
        ORIGINAL_MAIN_JS="${cursorPkg}/$possible_path"
        MODIFIED_MAIN_JS="${modifiedCursor}/$possible_path"
        break
      fi
    done

    if [ -n "$ORIGINAL_MAIN_JS" ] && [ -f "$MODIFIED_MAIN_JS" ]; then
      echo "📄 Main.js Differences (Electron Options):"
      echo "-------------------------------------------"
      if diff -q "$ORIGINAL_MAIN_JS" "$MODIFIED_MAIN_JS" > /dev/null; then
        echo "No differences found in main.js"
      else
        echo "Original: $ORIGINAL_MAIN_JS"
        echo "Modified: $MODIFIED_MAIN_JS"
        echo ""
        # Show context around changes
        diff -u "$ORIGINAL_MAIN_JS" "$MODIFIED_MAIN_JS" | head -50
        echo ""
        echo "(Showing first 50 lines of diff. Use 'diff -u \"$ORIGINAL_MAIN_JS\" \"$MODIFIED_MAIN_JS\"' for full diff)"
      fi
    else
      echo "⚠️  Could not find main.js files to compare"
    fi

    echo ""
    echo "🌐 Workbench HTML Differences (Custom CSS/JS):"
    echo "----------------------------------------------"

    # Find workbench HTML files
    ORIGINAL_WORKBENCH=""
    MODIFIED_WORKBENCH=""

    # Try different possible locations for workbench HTML
    for possible_path in \
      "share/cursor/resources/app/out/vs/code/electron-sandbox/workbench/workbench.html" \
      "usr/share/cursor/resources/app/out/vs/code/electron-sandbox/workbench/workbench.html" \
      "share/cursor/resources/app/out/vs/code/electron-sandbox/workbench/workbench.esm.html" \
      "share/cursor/resources/app/out/vs/code/electron-sandbox/workbench/workbench-apc-extension.html"
    do
      if [ -f "${cursorPkg}/$possible_path" ]; then
        ORIGINAL_WORKBENCH="${cursorPkg}/$possible_path"
        MODIFIED_WORKBENCH="${modifiedCursor}/$possible_path"
        break
      fi
    done

    if [ -n "$ORIGINAL_WORKBENCH" ] && [ -f "$MODIFIED_WORKBENCH" ]; then
      if diff -q "$ORIGINAL_WORKBENCH" "$MODIFIED_WORKBENCH" > /dev/null; then
        echo "No differences found in workbench HTML"
      else
        echo "Original: $ORIGINAL_WORKBENCH"
        echo "Modified: $MODIFIED_WORKBENCH"
        echo ""
        # Show only the injected content (look for our markers)
        if grep -q "CURSOR-CUSTOM-CSS-START" "$MODIFIED_WORKBENCH"; then
          echo "🎨 Injected Custom CSS/JS Content:"
          echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
          sed -n '/<!-- !! CURSOR-CUSTOM-CSS-START !! -->/,/<!-- !! CURSOR-CUSTOM-CSS-END !! -->/p' "$MODIFIED_WORKBENCH"
          echo ""
        fi

        # Show context diff of the end of the file where injection happens
        echo "📍 HTML Injection Point (last 20 lines):"
        echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
        diff -u "$ORIGINAL_WORKBENCH" "$MODIFIED_WORKBENCH" | tail -30
      fi
    else
      echo "⚠️  Could not find workbench HTML files to compare"
    fi

    echo ""
    echo "💡 Tips:"
    echo "--------"
    echo "• Use 'cursor-ui-info' for configuration details"
    echo "• Run 'cursor-styled' to launch the modified version"
    echo "• Run 'cursor' to launch the original version (if installed separately)"
    echo "• Full diffs: diff -u <original> <modified>"
    echo "• Check injected CSS: grep -A 50 'CURSOR-CUSTOM-CSS-START' \"$MODIFIED_WORKBENCH\""
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
      cursorUIDiffScript
    ];

    # Add some helpful information
    warnings = (optionals (cfg.enable && cfg.electron != { }) [''
      cursor-ui-style: Applied electron options: ${builtins.toJSON cfg.electron}

      Note: Changes require a complete restart of Cursor to take effect.
      The modified version is available as 'cursor-styled'.
      Run 'cursor-ui-info' for more details about the modifications.
    '']) ++ (optionals (cfg.enable && cfg.customCSS.imports != [ ]) [''
      cursor-ui-style: Injected ${
        toString (length cfg.customCSS.imports)
      } custom CSS/JS file(s) into Cursor

      Files: ${lib.concatStringsSep ", " (map toString cfg.customCSS.imports)}
      Status bar indicator: ${
        if cfg.customCSS.statusBar then "enabled" else "disabled"
      }

      Note: Changes require a complete restart of Cursor to take effect.
      The modified version is available as 'cursor-styled'.
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
