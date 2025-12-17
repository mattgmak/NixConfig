{ pkgs, inputs, hostname, username, pkgs-for-cursor, ... }: {
  nixpkgs.hostPlatform = "aarch64-darwin";
  nixpkgs.config.allowUnfree = true;
  system.stateVersion = 6;
  nix = { enable = false; };

  nixpkgs.overlays = [ inputs.nix4vscode.overlays.default ];

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
    extraSpecialArgs = { inherit inputs hostname username pkgs-for-cursor; };
    backupFileExtension = "hm-backup";
    users.${username} =
      import ../../home-manager/home.nix { inherit hostname username pkgs; };
  };

  environment.variables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
    DEVELOPER_DIR = "/Applications/Xcode.app/Contents/Developer";
    SHELL = "${pkgs.nushell}/bin/nu";
  };

  environment.systemPackages = with pkgs;
    [
      git
      neovim
      yazi
      fzf
      zoxide
      starship
      ripgrep
      nixfmt-classic
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
      jq # Required for yabai window focusing scripts
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
    ] ++ (with pkgs.darwin; [ file_cmds text_cmds developer_cmds ]);

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
    noto-fonts-emoji
  ];

  services.yabai = {
    enable = true;
    config = {
      # Layout and appearance
      layout = "bsp";
      auto_balance = "off";
      split_ratio = "0.50";

      # Gaps configuration (matching your Hyprland setup)
      top_padding = 0;
      bottom_padding = 8;
      left_padding = 8;
      right_padding = 8;
      window_gap = 5;

      # Window management
      window_placement = "second_child";
      window_topmost = "off";
      window_shadow = "on";
      window_opacity = "off";
      window_opacity_duration = "0.0";
      active_window_opacity = "1.0";
      normal_window_opacity = "0.90";

      # Window borders (optional - can be disabled)
      window_border = "off";
      window_border_width = 2;
      active_window_border_color = "0xff775759";
      normal_window_border_color = "0xff555555";

      # Mouse settings
      mouse_follows_focus = "off";
      focus_follows_mouse = "off";
      mouse_modifier = "fn";
      mouse_action1 = "move";
      mouse_action2 = "resize";
      mouse_drop_action = "swap";

      # General settings
      external_bar = "off";
      menubar_opacity = "1.0";
      window_animation_duration = "0.0";
    };

  };

  services.skhd = {
    enable = true;
    skhdConfig = ''
      # Focus navigation (matching your Hyprland jkl; layout)
      alt - j : yabai -m window --focus north
      alt - k : yabai -m window --focus south
      alt - l : yabai -m window --focus west
      alt - 0x29 : yabai -m window --focus east  # semicolon key

      # Alternative arrow key navigation
      # alt - up : yabai -m window --focus north
      # alt - down : yabai -m window --focus south
      # alt - left : yabai -m window --focus west
      # alt - right : yabai -m window --focus east

      # Move windows (shift + navigation)
      alt + shift - j : yabai -m window --swap north
      alt + shift - k : yabai -m window --swap south
      alt + shift - l : yabai -m window --swap west
      alt + shift - 0x29 : yabai -m window --swap east  # semicolon key

      # Alternative arrow key window movement
      # alt + shift - up : yabai -m window --swap north
      # alt + shift - down : yabai -m window --swap south
      # alt + shift - left : yabai -m window --swap west
      # alt + shift - right : yabai -m window --swap east

      # Window management
      alt - f : yabai -m window --toggle zoom-fullscreen
      alt - t : yabai -m window --toggle float
      alt - d : yabai -m window --close
      alt - tab : yabai -m space --focus recent

      # Workspace switching (1-8 like your Hyprland config)
      alt - 1 : yabai -m space --focus 1
      alt - 2 : yabai -m space --focus 2
      alt - 3 : yabai -m space --focus 3
      alt - 4 : yabai -m space --focus 4
      alt - 5 : yabai -m space --focus 5
      alt - 6 : yabai -m space --focus 6
      alt - 7 : yabai -m space --focus 7
      alt - 8 : yabai -m space --focus 8

      # Move windows to workspaces (shift + number)
      alt + shift - 1 : yabai -m window --space 1; yabai -m space --focus 1
      alt + shift - 2 : yabai -m window --space 2; yabai -m space --focus 2
      alt + shift - 3 : yabai -m window --space 3; yabai -m space --focus 3
      alt + shift - 4 : yabai -m window --space 4; yabai -m space --focus 4
      alt + shift - 5 : yabai -m window --space 5; yabai -m space --focus 5
      alt + shift - 6 : yabai -m window --space 6; yabai -m space --focus 6
      alt + shift - 7 : yabai -m window --space 7; yabai -m space --focus 7
      alt + shift - 8 : yabai -m window --space 8; yabai -m space --focus 8

      # Layout controls
      # alt - s : yabai -m space --layout stack
      # alt - w : yabai -m space --layout bsp
      # alt - e : yabai -m space --layout float

      # Resize windows (matching your Hyprland u/i/o/p layout)
      alt - u : yabai -m window --resize top:0:-20
      alt - i : yabai -m window --resize bottom:0:20
      alt - o : yabai -m window --resize left:-20:0
      alt - p : yabai -m window --resize right:20:0

      # Alternative resize with shift (move windows)
      alt + shift - u : yabai -m window --resize top:0:20
      alt + shift - i : yabai -m window --resize bottom:0:-20
      alt + shift - o : yabai -m window --resize left:20:0
      alt + shift - p : yabai -m window --resize right:-20:0

      # Application launchers (similar to your Hyprland super key bindings)
      # alt - return : open -a WezTerm

      # Focus specific applications (similar to your Hyprland focus binds)
      alt - w : yabai -m window --focus $(yabai -m query --windows | jq '.[] | select(.app=="Ghostty" or .app=="ghostty") | .id' | head -1)
      alt - e : yabai -m window --focus $(yabai -m query --windows | jq '.[] | select(.app=="Code" or .app=="Cursor") | .id' | head -1)
      alt - r : yabai -m window --focus $(yabai -m query --windows | jq '.[] | select(.app=="Zen" or .app=="zen") | .id' | head -1)
      alt - x : yabai -m window --focus $(yabai -m query --windows | jq '.[] | select(.app=="Xcode") | .id' | head -1)
      alt - a : yabai -m window --focus $(yabai -m query --windows | jq '.[] | select(.app=="Android Studio") | .id' | head -1)
      alt - s : yabai -m window --focus $(yabai -m query --windows | jq '.[] | select(.app=="Simulator") | .id' | head -1)

      # Balance all windows
      # alt + shift - space : yabai -m space --balance

      # Rotate tree
      # alt + shift - r : yabai -m space --rotate 90

      # Mirror tree y-axis
      # alt + shift - y : yabai -m space --mirror y-axis

      # Mirror tree x-axis
      # alt + shift - x : yabai -m space --mirror x-axis

      # Create new space and follow focus
      alt - n : yabai -m space --create && \
                         index="$(yabai -m query --spaces --display | jq 'map(select(."is-native-fullscreen" == false))[-1].index')" && \
                         yabai -m space --focus "$index"

      # Destroy current space
      alt + shift - q : yabai -m space --destroy
    '';
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
      NSGlobalDomain.ApplePressAndHoldEnabled = false;
    };
    primaryUser = username;
  };
}
