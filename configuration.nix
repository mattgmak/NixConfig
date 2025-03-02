# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running 'nixos-help').

{ pkgs, lib, inputs, hostname, username, ... }:

let
  system = pkgs.stdenv.hostPlatform.system;
  termfilechooser =
    (pkgs.callPackage ./packages/xdg-desktop-portal-termfilechooser { });
in {
  imports = [ # Include the results of the hardware scan.
    ./hardware-configuration.nix
    inputs.xremap-flake.nixosModules.default
  ];

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

  networking.hostName = hostname;

  # Enable networking
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
    NIXOS_OZONE_WL = "1";
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
    userName = "goofy";
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
    # Enable raw printing
    allowFrom = [ "all" ];
    # Enable raw printing
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

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  # Define a user account. Don't forget to set a password with 'passwd'.
  users.users.goofy = {
    isNormalUser = true;
    description = "Goofy";
    extraGroups = [ "networkmanager" "wheel" "adbusers" "input" ];
    shell = pkgs.nushell;
    # packages = with pkgs; [ ];
  };

  # Install firefox.
  programs.firefox.enable = true;

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
    input-remapper
    neofetch
    nitch
    nix-prefetch-github
    nvfetcher
    btop
    termfilechooser
    zenity
    gh
  ];

  # Input remapper
  services.input-remapper = {
    enable = true;
    package = pkgs.input-remapper;
  };
  systemd.services.StartInputRemapperDaemonAtLogin = {
    enable = true;
    description = "Start input-remapper daemon after login";
    serviceConfig = { Type = "simple"; };
    script = lib.getExe (pkgs.writeShellApplication {
      name = "start-input-mapper-daemon";
      runtimeInputs = with pkgs; [ input-remapper procps su ];
      text = ''
        until pgrep -u ${username}; do
          sleep 1
        done
        sleep 2
        until [ $(pgrep -c -u root "input-remapper") -gt 1 ]; do
          input-remapper-service&
          sleep 1
          input-remapper-reader-service&
          sleep 1
        done
        su ${username} -c "input-remapper-control --command stop-all"
        su ${username} -c "input-remapper-control --command autoload"
        sleep infinity
      '';
    });
    wantedBy = [ "default.target" ];
  };
  systemd.services.ReloadInputRemapperAfterSleep = {
    enable = true;
    description = "Reload input-remapper config after sleep";
    after = [ "suspend.target" ];
    serviceConfig = {
      User = "${username}";
      Type = "forking";
    };
    script = lib.getExe (pkgs.writeShellApplication {
      name = "reload-input-mapper-config";
      runtimeInputs = with pkgs; [ input-remapper ps gawk ];
      text = ''
        input-remapper-control --command stop-all
        input-remapper-control --command autoload
        sleep 1
        until [[ $(ps aux | awk '$11~"input-remapper" && $12="<defunct>" {print $0}' | wc -l) -eq 0 ]]; do
          input-remapper-control --command stop-all
          input-remapper-control --command autoload
          sleep 1
        done
      '';
    });
    wantedBy = [ "suspend.target" ];
  };

  nix.settings = {
    substituters =
      [ "https://hyprland.cachix.org" "https://nix-community.cachix.org" ];
    trusted-public-keys = [
      "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
    warn-dirty = false;
  };

  nix.gc = {
    automatic = true;
    dates = "daily";
    options = "--delete-older-than 5d";
  };

  programs.hyprland = {
    enable = true;
    package = inputs.hyprland.packages.${system}.hyprland;
    portalPackage =
      inputs.hyprland.packages.${system}.xdg-desktop-portal-hyprland;
  };

  xdg = {
    portal = {
      enable = true;
      xdgOpenUsePortal = true;
      config = {
        common.default = [ "gtk" ];
        hyprland.default = [ "hyprland" "gtk" ];
        hyprland."org.freedesktop.impl.portal.FileChooser" =
          [ "xdg-desktop-portal-termfilechooser" ];
      };
      extraPortals = [ pkgs.xdg-desktop-portal-gtk termfilechooser ];
    };
  };

  fonts.packages = with pkgs; [
    nerd-fonts.iosevka-term
    inter
    noto-fonts-cjk-serif
    noto-fonts-emoji
  ];

  stylix = {
    enable = true;
    polarity = "dark";
    # base16Scheme = "${pkgs.base16-schemes}/share/themes/dracula.yaml";
    base16Scheme = ./color-scheme.yaml;
    image = ./resources/beautiful-mountains-landscape.jpg;
    cursor = {
      package = pkgs.bibata-cursors;
      name = "Bibata-Modern-Ice";
    };
    fonts = {
      monospace = {
        package = pkgs.nerd-fonts.iosevka-term;
        name = "IosevkaTerm Nerd Font";
      };
      sansSerif = {
        package = pkgs.inter;
        name = "Inter";
      };
      serif = {
        package = pkgs.noto-fonts-cjk-sans;
        name = "Noto Sans CJK HK";
      };
      emoji = {
        package = pkgs.noto-fonts-emoji;
        name = "Noto Color Emoji";
      };
    };
  };

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  hardware.graphics.enable = true;
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings = { General = { Enable = "Source,Sink,Media,Socket"; }; };
  };
  services.blueman.enable = true;
  system.stateVersion = "24.11"; # Did you read the comment?
  home-manager.useGlobalPkgs = true;

  # Add flatpak support
  services.flatpak.enable = true;
}
