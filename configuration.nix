{ pkgs, inputs, hostname, username, ... }:

let
  system = pkgs.stdenv.hostPlatform.system;
  termfilechooser =
    (pkgs.callPackage ./packages/xdg-desktop-portal-termfilechooser { });
in {
  imports = [
    ./hosts/${hostname}/hardware-configuration.nix
    ./modules/input-remapper.nix
    ./modules/style
    inputs.xremap-flake.nixosModules.default
  ];

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

  # Bootloader.
  boot = {
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
    supportedFilesystems = [ "ntfs" ];
  };

  # fileSystems."/mnt/windows" = {
  #   device = "/dev/nvme0n1p5";
  #   fsType = "ntfs-3g"t;
  #   options = [ "rw" "uid=1000" ];
  # };

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
  services.xremap = {
    userName = username;
    withHypr = true;
    # Map CapsLock to Escape
    yamlConfig = ''
      modmap:
        - name: "CapsLock"
          remap:
            CapsLock: esc
    '';
  };

  # Enable CUPS to print documents.
  services.printing = {
    enable = true;
    drivers = with pkgs; [
      gutenprint
      hplip
      splix
      cups-kyocera
      foomatic-db
      foomatic-db-engine
      foomatic-db-ppds
      cups-filters
    ];
    # Enable browsing of printers that are shared on the network
    browsing = true;
    allowFrom = [ "all" ];
    listenAddresses = [ "*:631" ];
    defaultShared = true;
  };
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
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

  # Add onedrive service
  services.onedrive = {
    enable = true;
    package = pkgs.onedrive;
  };

  security.sudo.enable = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    #  vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
    wget
    git
    neovim
    inputs.zen-browser.packages."${system}".default
    bitwarden-cli
    bitwarden-desktop
    chezmoi
    pkgs.libsForQt5.kdeconnect-kde
    yazi
    wezterm
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
    libnotify
    kitty
    obsidian
    webcord
    protonvpn-gui
    wl-clipboard
    clipse
    pulseaudio-ctl
    brightnessctl
    playerctl
    bluetui
    networkmanagerapplet
    overskride
    nh
    nvd
    nix-output-monitor
    wev
    evtest
    neofetch
    nitch
    nix-prefetch-github
    nvfetcher
    btop
    termfilechooser
    zenity
    gh
    base16-shell-preview
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
          # Broken
          "org.freedesktop.impl.portal.FileChooser" = [ "termfilechooser" ];
        };
      };
      extraPortals = [ pkgs.xdg-desktop-portal-gtk termfilechooser ];
    };
  };

  hardware.graphics.enable = true;
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings = { General = { Enable = "Source,Sink,Media,Socket"; }; };
  };
  services.blueman.enable = true;
  system.stateVersion = "24.11";

  # Add flatpak support
  services.flatpak.enable = true;
}
