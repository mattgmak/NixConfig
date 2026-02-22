{
  flake.homeModules.cursorInjection =
    {
      config,
      lib,
      pkgs,
      ...
    }:

    with lib;

    let
      cfg = config.programs.cursor-injection;
      originalCursor = cfg.package;
      extendedCursor =
        let
          # Convert electron options to comma-separated key:value pairs for injection
          # This matches the format: key1:value1,key2:value2
          electronOptionsStr =
            if cfg.electron != { } then
              let
                jsonStr = builtins.toJSON cfg.electron;
                # Remove the outer braces from the JSON object
                innerJson = builtins.substring 1 ((builtins.stringLength jsonStr) - 2) jsonStr;
              in
              innerJson
            else
              "";

          # Extract backgroundColor if present for special handling
          hasBackgroundColor = cfg.electron ? backgroundColor;
          backgroundColor = if hasBackgroundColor then cfg.electron.backgroundColor else "";

          # Override the original cursor package instead of replacing it entirely
        in
        originalCursor.overrideAttrs (oldAttrs: {
          # Override postUnpack to modify extracted content directly
          postUnpack = (oldAttrs.postUnpack or "") + ''
            echo "Injecting cursor customizations..."

            # Get the extracted directory name
            ${optionalString pkgs.stdenv.isLinux ''extracted_dir=$(find . -maxdepth 1 -name "*extracted" -type d | head -1)''}
            ${optionalString pkgs.stdenv.isDarwin "extracted_dir=./Cursor.app/Contents"}
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
              # Patch main.js by injecting electron options inline
              echo "Patching main.js with electron options..."

              ${optionalString (electronOptionsStr != "") ''
                # Inject electron options after experimentalDarkMode:!0
                echo "Injecting electron options: ${electronOptionsStr}"
                sed -i 's/experimentalDarkMode:!0/experimentalDarkMode:!0,${electronOptionsStr}/g' "$mainjs_file"
              ''}

              ${optionalString hasBackgroundColor ''
                # Replace setBackgroundColor calls with custom color
                echo "Setting backgroundColor to: ${backgroundColor}"
                sed -i 's/setBackgroundColor([^)]*);/setBackgroundColor("${backgroundColor}");/g' "$mainjs_file"
              ''}

              echo "Successfully patched main.js"
            fi

            # Also try to find and modify any workbench.html files in extracted directory
            find "$extracted_dir" -name "workbench.html" -type f | while read -r htmlfile; do
              echo "Found workbench.html: $htmlfile"
              ${optionalString (cfg.customCSSFileStubs != [ ]) ''
                # Inject custom CSS file stubs into HTML
                ${concatMapStringsSep "\n" (fileName: ''
                  echo "Injecting CSS file: ${fileName}"
                  # Use printf to handle multiline content properly
                  printf '%s\n' "$(cat <<'EOF'
                  s|</head>| <!-- Custom CSS ${fileName} -->\n<link rel="stylesheet" href="vscode-file://vscode-app${config.home.homeDirectory}/.cursor/extensions/custom/${fileName}">\n</head>|
                  EOF
                  )" | sed -i -f - "$htmlfile"
                '') cfg.customCSSFileStubs}
              ''}
              ${optionalString (cfg.customJSFileStubs != [ ]) ''
                # Inject custom JS file stubs into HTML
                ${concatMapStringsSep "\n" (fileName: ''
                  echo "Injecting JS file: ${fileName}"
                  printf '%s\n' "$(cat <<'EOF'
                  s|</head>| <!-- Custom JS ${fileName} -->\n<script type="text/javascript" src="vscode-file://vscode-app${config.home.homeDirectory}/.cursor/extensions/custom/${fileName}"></script>\n</head>|
                  EOF
                  )" | sed -i -f - "$htmlfile"
                '') cfg.customJSFileStubs}
              ''}
            done

            echo "Cursor injection complete on extracted directory."
          '';
        });

    in
    {
      options.programs.cursor-injection = {
        enable = mkEnableOption "Cursor injection";

        package = mkOption {
          type = types.package;
          default = pkgs.code-cursor;
          defaultText = literalExpression "pkgs.code-cursor";
          description = "The cursor package to use as the base for injection";
          example = literalExpression "pkgs-for-cursor.code-cursor";
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

        customCSSFileStubs = mkOption {
          type = types.listOf types.str;
          default = [ ];
          description = "List of file stubs names to be injected into Cursor which will be loaded as CSS from the cursor extensions directory";
          example = [ "vscode.css" ];
        };

        customJSFileStubs = mkOption {
          type = types.listOf types.str;
          default = [ ];
          description = "List of file stubs names to be injected into Cursor which will be loaded as JS from the cursor extensions directory";
          example = [ "vscode.js" ];
        };
      };

      config = mkIf cfg.enable {
        # warnings = [
        #   (mkIf (cfg.electron != { }) ''
        #     cursor-injection:
        #     Applied electron options via overlay to extracted contents: ${builtins.toJSON cfg.electron}
        #   '')

        #   (mkIf (cfg.customCSSFileStubs != [ ] || cfg.customJSFileStubs != [ ]) ''
        #     cursor-injection:
        #     Injected custom CSS/JS into extracted Cursor contents via overlay
        #     - Custom CSS: ${concatStringsSep ", " cfg.customCSSFileStubs}
        #     - Custom JS: ${concatStringsSep ", " cfg.customJSFileStubs}
        #   '')
        # ];

        # Apply the overlay to the pinned pkgs-for-cursor instance and use the modified package
        programs.vscode.package = lib.mkForce extendedCursor;
        home.sessionPath = [ "${extendedCursor}/bin" ];
      };
    };
}
