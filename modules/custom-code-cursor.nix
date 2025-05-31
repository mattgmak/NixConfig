# /home/goofy/NixConfig/modules/custom-code-cursor.nix

# This function takes a packages set (pkgs) and returns a customized code-cursor package.
{ pkgs, # Expecting pkgs-for-cursor to be passed here
lib
, # For lib.optionalString etc. if needed, but not strictly for this basic patch
}: # Add other args like 'stdenv' if more complex patching is needed

let
  # The electron configuration to inject. Note the leading comma.
  electronConfigToInject =
    '',"frame":false,"titleBarStyle":"hiddenInset"''; # Escaped for Nix string
in pkgs.code-cursor.overrideAttrs (oldAttrs: {
  # Keep the original package name or customize it if you wish
  # pname = oldAttrs.pname + "-custom-frame";
  # version = oldAttrs.version;

  postPatch = (oldAttrs.postPatch or "") + ''
    echo "Applying custom frame patch to code-cursor..."

    # --- VERIFICATION REQUIRED BY USER ---
    # 1. FILE_TO_PATCH:
    #    Path to the main JS file relative to unpacked source root.
    #    Common paths:
    #    - "resources/app/out/vs/workbench/workbench.desktop.main.js"
    #    - "lib/vscode/out/main.js"
    #    - "lib/vscode/resources/app/out/vs/workbench/workbench.desktop.main.js"
    #    Inspect the package if the build fails here.
    # 2. ANCHOR_STRING:
    #    Unique string in FILE_TO_PATCH to append the config to.
    #    e.g., 'experimentalDarkMode:!0' or 'backgroundColor:"someValue"'
    # --- END VERIFICATION REQUIRED ---

    FILE_TO_PATCH=""
    CANDIDATE_PATHS=(
      "resources/app/out/vs/workbench/workbench.desktop.main.js"
      "lib/vscode/out/main.js" # Common in nixpkgs builds for vscode
      "lib/vscode/resources/app/out/vs/workbench/workbench.desktop.main.js"
    )

    echo "Searching for main JS file in code-cursor source..."
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
      echo "in modules/custom-code-cursor.nix (or the calling file)."
      echo "Listing current directory contents to aid debugging (relative to src):"
      ls -R .
      echo "---------------------------------------------------------------------"
      exit 1
    fi

    ANCHOR_STRING='experimentalDarkMode:!0'

    echo "Attempting to patch $FILE_TO_PATCH..."
    if grep -q "$ANCHOR_STRING" "$FILE_TO_PATCH"; then
      sed -i "s@$ANCHOR_STRING@$ANCHOR_STRING${electronConfigToInject}@g" "$FILE_TO_PATCH"
      echo "Successfully patched $FILE_TO_PATCH with custom frame options."
    else
      echo "---------------------------------------------------------------------"
      echo "ERROR: Anchor string '$ANCHOR_STRING' not found in $FILE_TO_PATCH."
      echo "You MUST inspect $FILE_TO_PATCH and find a suitable ANCHOR_STRING."
      echo "The patch attempts to change '$ANCHOR_STRING' to '$ANCHOR_STRING${electronConfigToInject}'."
      echo "Contents of $FILE_TO_PATCH start below (first 50 lines):"
      head -n 50 "$FILE_TO_PATCH"
      echo "---------------------------------------------------------------------"
      exit 1
    fi
  ''; # End of postPatch script
})
