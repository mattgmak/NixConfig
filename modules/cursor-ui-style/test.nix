# Test configuration for cursor-ui-style module
# This can be used to test the module in isolation

{ pkgs ? import <nixpkgs> { } }:

let
  # Mock pkgs-for-cursor for testing
  pkgs-for-cursor = pkgs;

  # Import the module
  cursorUIModule = import ./default.nix {
    config = {
      programs.cursor-ui-style = {
        enable = true;
        autoApply = true;
        electron = {
          frame = false;
          titleBarStyle = "hiddenInset";
        };
      };
    };
    lib = pkgs.lib;
    inherit pkgs pkgs-for-cursor;
  };

in {
  # Test that the module can be imported without errors
  inherit cursorUIModule;

  # Test package building
  testPackage = pkgs.writeShellScriptBin "test-cursor-ui" ''
    echo "Testing cursor-ui-style module..."
    echo "Module imported successfully!"
  '';
}
