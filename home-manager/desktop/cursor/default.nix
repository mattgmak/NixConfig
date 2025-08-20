{ hostname, ... }: {
  imports = [ ../../../modules/cursor-injection ];
  home.file = {
    ".cursor/extensions/custom/custom.js".source = ./custom.js;
    ".cursor/extensions/custom/custom.css".source = ./custom.css;
  };
  programs.cursor-injection = {
    enable = true;
    electron = {
      frame = false;
      titleBarStyle = "hiddenInset";
    };
    customCSSFileStubs = [ "custom.css" "test.css" ];
    customJSFileStubs = [ "custom.js" "test.js" ];
  };
  stylix.targets.vscode.enable = false;
  programs.vscode = {
    enable = true;
    mutableExtensionsDir = true;
    profiles = {
      default = {
        userSettings = import ./settings.nix { inherit hostname; };
        keybindings = import ./keybindings.nix;
        userMcp = import ./mcp.nix;
      };
    };
  };

}
