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
  # Add asar and file to nativeBuildInputs
  nativeBuildInputs = (oldAttrs.nativeBuildInputs or [ ]) ++ [ asar pkgs.file ];

  postPatch = # (oldAttrs.postPatch or "") + # Completely replace postPatch for now
    # Start of new debugging postPatch script
    ''
      set -x # Echo all commands
      set -e # Exit immediately if a command exits with a non-zero status.

      echo "--- Running custom postPatch for code-cursor (DEBUG MODE) ---"
      echo "Current directory (PWD): $(pwd)"
      echo "Listing current directory contents (-alR):"
      ls -alR .
      echo "--------------------------------------------------"

      if [ -n "$src" ]; then
        echo "DEBUG: Environment variable \$src is set to: $src"
        echo "DEBUG: File type of \$src ($src):"
        file "$src"
        echo "--------------------------------------------------"
        if [ -f "$src" ]; then
          echo "DEBUG: \$src is a file. Listing its details:"
          ls -lh "$src"
          echo "--------------------------------------------------"
          echo "DEBUG: Attempting to see if \$src is an AppImage and list its contents (may fail if not an AppImage or not executable):"
          # AppImages often support --appimage-extract or --appimage-list
          # This requires $src to be executable and an AppImage.
          # We also need appimage-tool in buildInputs if we were to use appimage-extract command directly.
          if [ -x "$src" ]; then
            "$src" --appimage-list || echo "DEBUG: '$src --appimage-list' failed or not supported."
          else
            echo "DEBUG: \$src ($src) is not executable. Cannot run --appimage-list directly."
          fi
          echo "--------------------------------------------------"
        elif [ -d "$src" ]; then
          echo "DEBUG: \$src ($src) is a directory. Listing its contents (-alR):"
          ls -alR "$src"
          echo "--------------------------------------------------"
        else
          echo "DEBUG: \$src ($src) is neither a regular file nor a directory."
          echo "--------------------------------------------------"
        fi
      else
        echo "DEBUG: Environment variable \$src is not set or is empty."
        echo "--------------------------------------------------"
      fi

      echo "--- End of custom postPatch (DEBUG MODE) ---"
      echo "DEBUG: Exiting intentionally with 0 to show debug output. Remove 'exit 0' to continue build."
      exit 0 # Intentionally exit to see the debug output
      # The original script logic would go here if we weren't debugging.
    ''; # End of postPatch script
})
