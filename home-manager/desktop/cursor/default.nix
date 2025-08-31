{ hostname, pkgs, ... }: {
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
        enableUpdateCheck = false;
        enableExtensionUpdateCheck = false;
        userSettings = import ./settings.nix { inherit hostname; };
        keybindings = import ./keybindings.nix;
        userMcp = import ./mcp.nix;
        extensions = let
          # decorators = {
          #   "helgardrichard.helium-icon-theme" = {
          #     postPatch = ''
          #       sed -i '/\"helium-icon-theme\.hidesExplorerArrows\": {/,/},/{
          #         s/"default": false,/"default": true,/
          #       }' package.json
          #     '';
          #   };
          # };
        in with pkgs.vscode-extensions;
        [
          sumneko.lua
          tamasfe.even-better-toml
          davidanson.vscode-markdownlint
          mkhl.direnv
          usernamehw.errorlens
        ] ++ pkgs.nix4vscode.forVscodeVersion "1.99.3" [
          "ms-vsliveshare.vsliveshare.1.0.5905"
          "github.vscode-pull-request-github"
          "bbenoist.QML"
          "delgan.qml-format"
          "eamodio.gitlens"
          "asvetliakov.vscode-neovim"
          "johnnymorganz.stylua"
          "denoland.vscode-deno"
          "bradlc.vscode-tailwindcss"
          "dbaeumer.vscode-eslint"
          "vscode-icons-team.vscode-icons"
          "jnoortheen.nix-ide"
          "jeronimoekerdt.color-picker-universal"
          "mylesmurphy.prettify-ts"
          "thenuprojectcontributors.vscode-nushell-lang"
          "redhat.vscode-yaml"
          "chflick.firecode"
          "vsls-contrib.gistfs"
          "dlasagno.rasi"
          "ecmel.vscode-html-css"
          "pmneo.tsimporter"
          "yoavbls.pretty-ts-errors"
          "esbenp.prettier-vscode"
          "ryuta46.multi-command"
          "wholroyd.jinja"
          # "helgardrichard.helium-icon-theme"
          "bierner.emojisense"
          "mikestead.dotenv"
          "aaron-bond.better-comments"
          "formulahendry.auto-rename-tag"
          "formulahendry.auto-close-tag"
          "daltonmenezes.aura-theme"
          "christian-kohler.path-intellisense"
          "biomejs.biome"
        ];
      };
    };
  };

}
