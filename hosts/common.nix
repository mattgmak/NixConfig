{ pkgs, inputs, hostname, username, ... }:

let
  termfilechooser =
    (pkgs.callPackage ../packages/xdg-desktop-portal-termfilechooser { });
in {
  imports = [
    ../modules/input-remapper.nix
    ../modules/style
    inputs.home-manager.nixosModules.home-manager
    inputs.stylix.nixosModules.stylix
  ];

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = { inherit inputs hostname; };
    backupFileExtension = "hm-backup";
    users."${username}" = import ../home-manager/home.nix { inherit hostname; };
  };

  nix = {
    settings = {
      substituters =
        [ "https://hyprland.cachix.org" "https://nix-community.cachix.org" ];
      trusted-public-keys = [
        "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      ];
      warn-dirty = false;
      experimental-features = [ "nix-command" "flakes" ];
    };
    gc = {
      automatic = true;
      dates = "daily";
      options = "--delete-older-than 7d";
    };
  };

  # Enable networking
  networking.hostName = hostname;
  networking.networkmanager.enable = true;
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 80 443 3000 8081 ];
    allowedUDPPorts = [ 80 443 ];
  };

  environment.sessionVariables = {
    FLAKE = "/home/${username}/NixConfig";
    TERMINAL = "wezterm";
    BROWSER = "zen";
    GTK_USE_PORTAL = "1";
    # Disaabled for obsidian because no stylus support
    # NIXOS_OZONE_WL = "1";
  };
  environment.shells = with pkgs; [ nushell bash ];

  # Set your time zone.
  time.timeZone = "Asia/Hong_Kong";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_HK.UTF-8";

  # Enable the X11 windowing system.
  services.xserver.enable = true;

  # Enable the GNOME Desktop Environment.
  services.xserver.displayManager.gdm.enable = true;
  services.xserver.desktopManager.gnome.enable = true;

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  # Enable sound with pipewire.
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
  };

  # Define a user account. Don't forget to set a password with 'passwd'.
  users.users.${username} = {
    isNormalUser = true;
    description = "Goofy";
    extraGroups = [ "networkmanager" "wheel" "adbusers" "input" ];
    shell = pkgs.nushell;
  };

  security.sudo.enable = true;

  environment.systemPackages = with pkgs; [
    wget
    git
    neovim
    chezmoi
    yazi
    appimage-run
    nushell
    fzf
    zoxide
    starship
    ripgrep
    zip
    unzip
    nixfmt-classic
    atuin
    nixd
    kitty
    nh
    nvd
    nix-output-monitor
    neofetch
    nitch
    nix-prefetch-github
    nvfetcher
    termfilechooser
    zenity
    gh
    base16-shell-preview
    lazygit
    appflowy
    nurl
  ];

  programs.hyprland = {
    enable = true;
    # package = inputs.hyprland.packages.${system}.hyprland;
    # portalPackage =
    #   inputs.hyprland.packages.${system}.xdg-desktop-portal-hyprland;
  };

  xdg = {
    portal = {
      enable = true;
      # xdgOpenUsePortal = true;
      config = {
        hyprland = {
          default = [ "hyprland" "gtk" ];
          "org.freedesktop.impl.portal.FileChooser" = [ "termfilechooser" ];
        };
      };
      extraPortals = [ pkgs.xdg-desktop-portal-gtk termfilechooser ];
    };
  };

  # Add flatpak support
  services.flatpak.enable = true;
}
