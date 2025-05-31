{ lib, config, pkgs, ... }:

let
  cfg = config.programs.code-cursor;
  # The electron configuration to inject. Note the leading comma.
  electronConfigToInject =
    '',"frame":false,"titleBarStyle":"hiddenInset"''; # Escaped for Nix string
in {
  options.programs.code-cursor.enableCustomFrame = lib.mkEnableOption
    "Apply custom frame (frameless, hiddenInset titlebar) to code-cursor.";

  config = lib.mkIf cfg.enableCustomFrame {
    # This overlay will modify the code-cursor package.
    # It assumes that the 'pkgs' set used for this NixOS configuration
    # is the one derived from 'pkgs-for-cursor' as per your flake.nix.
    nixpkgs.overlays = [
      (final: prev: {
        code-cursor = prev.code-cursor.overrideAttrs (oldAttrs: {
          postPatch = (oldAttrs.postPatch or "") + ''
            echo "Applying custom frame patch to code-cursor..."

            # --- VERIFICATION REQUIRED BY USER ---
            # 1. FILE_TO_PATCH:
            #    The path to the main JavaScript file for code-cursor's Electron app,
            #    relative to the unpacked source root during the Nix build.
            #    Common paths for VSCode-based editors:
            #    - "resources/app/out/vs/workbench/workbench.desktop.main.js" (standard structure)
            #    - "lib/vscode/out/main.js" (common in nixpkgs builds for vscode)
            #    - "lib/vscode/resources/app/out/vs/workbench/workbench.desktop.main.js"
            #
            #    Build code-cursor once without this patch to inspect its contents in:
            #    /nix/store/...-code-cursor-.../ and find the correct file.
            #
            # 2. ANCHOR_STRING:
            #    A unique string within FILE_TO_PATCH where the new config will be appended.
            #    It should be part of an existing options object for the BrowserWindow constructor.
            #    The vscode-custom-ui-style extension used 'experimentalDarkMode:!0'.
            #    If this string exists and is suitable, use it. Otherwise, find another one,
            #    e.g., 'backgroundColor:"someValue"' or similar.
            # --- END VERIFICATION REQUIRED ---

            FILE_TO_PATCH=""
            CANDIDATE_PATHS=(
              "resources/app/out/vs/workbench/workbench.desktop.main.js"
              "lib/vscode/out/main.js" # Common in nixpkgs builds for vscode
              "lib/vscode/resources/app/out/vs/workbench/workbench.desktop.main.js"
            )

            echo "Searching for main JS file in code-cursor source..."
            # Correctly iterate over bash array in a Nix string
            for p in "''${CANDIDATE_PATHS[@]}"; do
              if [ -f "$p" ]; then
                FILE_TO_PATCH="$p"
                echo "Found main JS file at: $p"
                break
              fi
            done

            if [ -z "$FILE_TO_PATCH" ]; then
              echo "---------------------------------------------------------------------"
              echo "ERROR: Could not find code-cursor's main JavaScript file to patch."
              echo "Please inspect the code-cursor package contents (e.g., build it once"
              echo "and look in /nix/store/...-code-cursor-...) and update CANDIDATE_PATHS"
              echo "in modules/custom-code-cursor.nix."
              echo "Listing current directory contents to aid debugging (relative to src):"
              ls -R .
              echo "---------------------------------------------------------------------"
              exit 1
            fi

            # This anchor is from the vscode-custom-ui-style extension. Verify it exists in your FILE_TO_PATCH.
            ANCHOR_STRING='experimentalDarkMode:!0'
            # electronConfigToInject is a Nix variable, it needs to be passed into the shell script.
            # We use "${electronConfigToInject}" to insert its value.
            # Ensure electronConfigToInject is properly escaped if it contains special shell characters.
            # In this case, it's JSON-like, so quotes are important.

            echo "Attempting to patch $FILE_TO_PATCH..."
            # Using @ as sed delimiter due to potential special chars in ANCHOR_STRING or electronConfigToInject
            if grep -q "$ANCHOR_STRING" "$FILE_TO_PATCH"; then
              # Correctly use the Nix variable in sed
              sed -i "s@$ANCHOR_STRING@$ANCHOR_STRING${electronConfigToInject}@g" "$FILE_TO_PATCH"
              echo "Successfully patched $FILE_TO_PATCH with custom frame options."
            else
              echo "---------------------------------------------------------------------"
              echo "ERROR: Anchor string '$ANCHOR_STRING' not found in $FILE_TO_PATCH."
              echo "You MUST inspect $FILE_TO_PATCH and find a suitable ANCHOR_STRING."
              echo "This string should be part of the options object for the main Electron window."
              echo "The patch attempts to change '$ANCHOR_STRING' to '$ANCHOR_STRING${electronConfigToInject}'."
              echo "Contents of $FILE_TO_PATCH start below (first 50 lines):"
              head -n 50 "$FILE_TO_PATCH"
              echo "---------------------------------------------------------------------"
              exit 1
            fi
          ''; # End of postPatch script
        });
      })
    ];
  };
}
