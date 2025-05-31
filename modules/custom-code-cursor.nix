# /home/goofy/NixConfig/modules/custom-code-cursor.nix

# This function takes a packages set (pkgs), lib, and the asar tool,
# and returns a customized code-cursor package.
{ pkgs, # Expecting pkgs-for-cursor to be passed here
lib, asar, # The asar package for extracting .asar files
}:

let
  electronConfigToInject =
    '',"frame":false,"titleBarStyle":"hiddenInset"''; # Escaped for Nix string
in pkgs.code-cursor.overrideAttrs (oldAttrs: {
  # Add asar to nativeBuildInputs so it's available in postPatch
  nativeBuildInputs = (oldAttrs.nativeBuildInputs or [ ]) ++ [ asar ];

  postPatch = (oldAttrs.postPatch or "") + ''
    set -x # Echo all commands for better debugging
    echo "--- Running custom postPatch for code-cursor ---"
    echo "Current directory: $(pwd)"
    echo "Listing current directory contents (-alR):"
    ls -alR .
    echo "--------------------------------------------------"

    echo "Searching for app.asar in the current directory and subdirectories..."
    # Try to find app.asar, it might be in a subdirectory like squashfs-root
    APP_ASAR_PATH=$(find . -name app.asar -print -quit)

    if [ -z "$APP_ASAR_PATH" ]; then
      echo "---------------------------------------------------------------------"
      echo "ERROR: app.asar not found in the extracted AppImage source."
      echo "Build logs above show the directory structure."
      echo "Please check if 'app.asar' exists and adjust the find command or path if needed."
      echo "---------------------------------------------------------------------"
      exit 1
    fi

    echo "Found app.asar at: $APP_ASAR_PATH"
    mkdir -p app_unpacked # Create directory, -p ignores if exists
    echo "Extracting $APP_ASAR_PATH to app_unpacked..."
    # Use the asar executable from the asar package passed in
    ${asar}/bin/asar extract "$APP_ASAR_PATH" app_unpacked

    cd app_unpacked # IMPORTANT: Operations are now relative to app_unpacked
    echo "Current directory changed to: $(pwd)"
    echo "Listing contents of app_unpacked (-alR):"
    ls -alR .
    echo "--------------------------------------------------"

    FILE_TO_PATCH=""
    # These paths are relative to the root of the unpacked asar archive
    CANDIDATE_PATHS=(
      "out/vs/workbench/workbench.desktop.main.js"
      "browser/workbench/workbench.desktop.main.js"
      "electron-browser/workbench/workbench.desktop.main.js" # Another common path
      "vs/workbench/workbench.desktop.main.js" # If no out/ or browser/ prefix
    )

    echo "Searching for main JS file in app_unpacked..."
    for p in "''${CANDIDATE_PATHS[@]}"; do
      if [ -f "$p" ]; then
        FILE_TO_PATCH="$p"
        echo "Found main JS file at (relative to asar root): $p"
        break
      fi
    done

    if [ -z "$FILE_TO_PATCH" ]; then
      echo "---------------------------------------------------------------------"
      echo "ERROR: Could not find main JavaScript file to patch within app_unpacked."
      echo "Build logs above show the directory structure of app_unpacked."
      echo "Update CANDIDATE_PATHS in modules/custom-code-cursor.nix."
      echo "---------------------------------------------------------------------"
      exit 1
    fi

    ANCHOR_STRING='experimentalDarkMode:!0'
    # Alternative anchor example: ANCHOR_STRING='backgroundColor:"

    echo "Attempting to patch $FILE_TO_PATCH with electronConfig: ${electronConfigToInject}"
    # Make sure the anchor string actually exists
    if ! grep -q "$ANCHOR_STRING" "$FILE_TO_PATCH"; then
      echo "---------------------------------------------------------------------"
      echo "ERROR: Anchor string '$ANCHOR_STRING' not found in $FILE_TO_PATCH."
      echo "You MUST inspect $FILE_TO_PATCH (contents below) and find a suitable ANCHOR_STRING."
      echo "The patch attempts to change '$ANCHOR_STRING' to '$ANCHOR_STRING${electronConfigToInject}'."
      echo "---- First 50 lines of $FILE_TO_PATCH ----"
      head -n 50 "$FILE_TO_PATCH"
      echo "---------------------------------------------------------------------"
      exit 1
    fi

    # Perform the substitution
    # Using @ as sed delimiter because ANCHOR_STRING might contain /
    sed -i "s@$ANCHOR_STRING@$ANCHOR_STRING${electronConfigToInject}@g" "$FILE_TO_PATCH"
    echo "Successfully patched $FILE_TO_PATCH."

    cd .. # Go back to the original source root before Nix build continues
    echo "Changed directory back to: $(pwd)"
    echo "--- Finished custom postPatch for code-cursor ---"
    set +x
  ''; # End of postPatch script
})
