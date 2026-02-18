{ inputs, self, ... }:
let
  hostname = self.constants.macMiniName;
in
{
  flake.darwinConfigurations.${hostname} = inputs.nix-darwin.lib.darwinSystem {
    specialArgs = rec {
      system = "aarch64-darwin";
      inherit inputs hostname;
      inherit (self.legacyPackages.${system}) pkgs-stable pkgs-for-cursor;
      username = "mattgmak";
    };
    modules = [
      self.darwinModules.${hostname}
      self.nixpkgsConfig
    ];
  };

  flake.homeConfigurations.MacMini = {
    imports = with self.homeModules; [
      darwin-home
      zen-browser
      nushell
      wezterm
      neovim
      starship
      yazi
      git
      direnv
      lazygit
      ghostty
      cursor
      carapace
    ];
  };

  flake.darwinModules.${hostname} =
    {
      pkgs,
      hostname,
      username,
      pkgs-for-cursor,
      ...
    }:
    {
      nixpkgs.hostPlatform = "aarch64-darwin";
      system.stateVersion = 6;
      nix = {
        enable = false;
      };

      imports = [
        # ./common.nix
        inputs.home-manager.darwinModules.home-manager
        inputs.nix-homebrew.darwinModules.nix-homebrew
        inputs.stylix.darwinModules.stylix
        ../../modules/style/common.nix
      ];

      users.users.${username} = {
        home = "/Users/${username}";
        shell = pkgs.nushell;
      };

      home-manager = {
        useGlobalPkgs = true;
        useUserPackages = true;
        extraSpecialArgs = {
          inherit
            inputs
            hostname
            username
            pkgs-for-cursor
            ;
        };
        backupFileExtension = "hm-backup";
        users.${username} = self.homeConfigurations.MacMini;
      };

      environment.variables = {
        EDITOR = "nvim";
        VISUAL = "nvim";
        DEVELOPER_DIR = "/Applications/Xcode.app/Contents/Developer";
        SHELL = "${pkgs.nushell}/bin/nu";
      };

      environment.systemPackages =
        with pkgs;
        [
          git
          fzf
          zoxide
          starship
          ripgrep
          nixfmt
          atuin
          nixd
          nh
          nvd
          nix-output-monitor
          neofetch
          gh
          base16-shell-preview
          lazygit
          wezterm
          jq
          mas
          direnv
          git-credential-manager
          cocoapods
          ruby_3_4
          nix-search-cli
          delta
          swift-format
          swiftlint
          xcbeautify
          sourcekit-lsp
          btop
          dua
          nodejs_20
          bat
          eza
          ollama
          stylua
        ]
        ++ (with pkgs.darwin; [
          file_cmds
          text_cmds
          developer_cmds
        ]);

      nix-homebrew = {
        enable = true;
        enableRosetta = true;
        user = username;
        autoMigrate = true;
      };

      homebrew = {
        enable = true;
        casks = [
          "google-chrome"
          "github-copilot-for-xcode"
          "vial"
          "android-studio"
          "android-platform-tools"
          "locationsimulator"
          "zulu@17"
          "chromium"
          "ghostty"
        ];
        brews = [ "xcode-build-server" ];
        onActivation.cleanup = "zap";
        # masApps = { "Yoink" = 457622435; };
      };

      fonts.packages = with pkgs; [
        nerd-fonts.iosevka-term
        inter
        noto-fonts-cjk-serif
        noto-fonts-color-emoji
      ];

      services.aerospace = {
        enable = true;
        settings = {
          "config-version" = 2;
          "default-root-container-layout" = "tiles";
          "default-root-container-orientation" = "auto";
          "enable-normalization-flatten-containers" = true;
          "enable-normalization-opposite-orientation-for-nested-containers" = true;
          "accordion-padding" = 30;

          "key-mapping"."preset" = "qwerty";

          # Match prior yabai gap behavior as closely as possible.
          gaps = {
            inner = {
              horizontal = 5;
              vertical = 5;
            };
            outer = {
              left = 0;
              bottom = 0;
              top = 0;
              right = 0;
            };
          };

          mode.main.binding = {
            # Focus navigation (matching previous j/k/l/; directional mapping)
            "alt-j" = "focus up";
            "alt-k" = "focus down";
            "alt-l" = "focus left";
            "alt-semicolon" = "focus right";

            # Swap windows
            "alt-shift-j" = "swap up";
            "alt-shift-k" = "swap down";
            "alt-shift-l" = "swap left";
            "alt-shift-semicolon" = "swap right";

            # Window management
            "alt-f" = "fullscreen";
            "alt-t" = "layout floating tiling";
            "alt-d" = "close";

            # Workspace switching
            "alt-0" = "workspace 0";
            "alt-1" = "workspace 1";
            "alt-2" = "workspace 2";
            "alt-3" = "workspace 3";
            "alt-4" = "workspace 4";
            "alt-5" = "workspace 5";
            "alt-6" = "workspace 6";
            "alt-7" = "workspace 7";
            "alt-8" = "workspace 8";
            "alt-9" = "workspace 9";

            # Move windows to workspaces
            "alt-shift-0" = "move-node-to-workspace --focus-follows-window 0";
            "alt-shift-1" = "move-node-to-workspace --focus-follows-window 1";
            "alt-shift-2" = "move-node-to-workspace --focus-follows-window 2";
            "alt-shift-3" = "move-node-to-workspace --focus-follows-window 3";
            "alt-shift-4" = "move-node-to-workspace --focus-follows-window 4";
            "alt-shift-5" = "move-node-to-workspace --focus-follows-window 5";
            "alt-shift-6" = "move-node-to-workspace --focus-follows-window 6";
            "alt-shift-7" = "move-node-to-workspace --focus-follows-window 7";
            "alt-shift-8" = "move-node-to-workspace --focus-follows-window 8";
            "alt-shift-9" = "move-node-to-workspace --focus-follows-window 9";

            # Resize windows (closest AeroSpace equivalents)
            "alt-u" = "resize height -50";
            "alt-i" = "resize height +50";
            "alt-o" = "resize width -50";
            "alt-p" = "resize width +50";
            "alt-shift-u" = "resize height +50";
            "alt-shift-i" = "resize height -50";
            "alt-shift-o" = "resize width +50";
            "alt-shift-p" = "resize width -50";

            # Focus key apps
            "alt-w" = "exec-and-forget osascript -e 'tell application \"Ghostty\" to activate'";
            "alt-e" = "exec-and-forget osascript -e 'tell application \"Cursor\" to activate'";
            "alt-r" = "exec-and-forget osascript -e 'tell application \"Zen\" to activate'";
            "alt-x" = "exec-and-forget osascript -e 'tell application \"Xcode\" to activate'";
            "alt-a" = "exec-and-forget osascript -e 'tell application \"Android Studio\" to activate'";
            "alt-s" = "exec-and-forget osascript -e 'tell application \"Simulator\" to activate'";
            "alt-c" = "exec-and-forget osascript -e 'tell application \"Google Chrome\" to activate'";

          };

          on-window-detected = [
            {
              "if".app-id = "com.mitchellh.ghostty";
              run = "layout floating";
            }
          ];
        };
      };

      system = {
        defaults = {
          finder = {
            AppleShowAllFiles = true;
            AppleShowAllExtensions = true;
          };
          dock = {
            autohide = true;
            persistent-apps = [ ];
          };
          NSGlobalDomain = {
            ApplePressAndHoldEnabled = false;
            _HIHideMenuBar = true;
          };
        };
        primaryUser = username;
      };
    };

}
