{ pkgs, inputs, hostname, username, pkgs-for-cursor, config, lib, ... }: {
  imports = [
    ../modules/input-remapper.nix
    ../modules/style/common.nix
    ../modules/style/linux.nix
    inputs.home-manager.nixosModules.home-manager
    inputs.stylix.nixosModules.stylix
  ];

  nixpkgs.overlays = [
    (final: prev: {
      zen = inputs.zen-browser.packages.${prev.system}.zen-browser;
    })
    inputs.nix4vscode.overlays.default
  ];

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = { inherit inputs hostname username pkgs-for-cursor; };
    backupFileExtension = "hm-backup-1";
    users."${username}" = import ../home-manager/home.nix {
      inherit hostname username pkgs inputs lib;
    };
  };

  nixpkgs.config.allowUnfree = true;

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
    allowedTCPPortRanges = [
      # KDEConnect
      {
        from = 1714;
        to = 1764;
      }
    ];
    allowedUDPPortRanges = [
      # KDEConnect
      {
        from = 1714;
        to = 1764;
      }
    ];
  };
  environment.sessionVariables = {
    NH_OS_FLAKE = "/home/${username}/NixConfig";
    TERMINAL = "ghostty";
    BROWSER = "zen";
    GTK_USE_PORTAL = "1";
    # Disaabled for obsidian because no stylus support
    # NIXOS_OZONE_WL = "1";
  };
  environment.shells = with pkgs; [ nushell bash ];

  systemd.services.fprintd = {
    wantedBy = [ "multi-user.target" ];
    serviceConfig.Type = "simple";
  };
  services.fprintd = { enable = true; };
  security.pam.services.login = {
    fprintAuth = false;
    enableGnomeKeyring = true;
  };
  security.pam.services.gdm-fingerprint =
    lib.mkIf (config.services.fprintd.enable) {
      text = ''
        auth       required                    pam_shells.so
        auth       requisite                   pam_nologin.so
        auth       requisite                   pam_faillock.so      preauth
        auth       required                    ${pkgs.fprintd}/lib/security/pam_fprintd.so
        auth       optional                    pam_permit.so
        auth       required                    pam_env.so
        auth       [success=ok default=1]      ${pkgs.gdm}/lib/security/pam_gdm.so
        auth       optional                    ${pkgs.gnome-keyring}/lib/security/pam_gnome_keyring.so

        account    include                     login

        password   required                    pam_deny.so

        session    include                     login
        session    optional                    ${pkgs.gnome-keyring}/lib/security/pam_gnome_keyring.so auto_start
      '';
    };
  services.gnome.gnome-keyring.enable = true;
  programs.seahorse.enable = true;
  security.pam.services = {
    greetd.enableGnomeKeyring = true;
    greetd-password.enableGnomeKeyring = true;
  };
  services.dbus.packages = with pkgs; [ gnome-keyring gcr ];

  services.xserver.displayManager.sessionCommands = ''
    eval $(gnome-keyring-daemon --start --daemonize --components=ssh,secrets)
    export SSH_AUTH_SOCK
  '';

  # Set your time zone.
  time.timeZone = "Asia/Hong_Kong";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_HK.UTF-8";

  # Enable the X11 windowing system.
  services.xserver.enable = true;

  # Enable the GNOME Desktop Environment.
  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;

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
    extraGroups =
      [ "networkmanager" "wheel" "adbusers" "input" "kvm" "dialout" ];
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
    zenity
    gh
    base16-shell-preview
    lazygit
    nurl
    dua
    nautilus
    kdePackages.dolphin
    git-credential-manager
    kdePackages.kdeconnect-kde
    lazyjournal
    zen
    stylua
    inputs.wiremix.packages.${pkgs.system}.wiremix
    ffmpeg
    uwsm
  ];

  services.syncthing = {
    enable = true;
    openDefaultPorts = true;
    user = username;
    group = "users";
    configDir = "/home/${username}/.config/syncthing";
    settings = {
      devices = {
        phone.id =
          "LRGIDSH-W6NIW7U-SV62HMC-EMHYALK-RSK7Y5K-OOZK7WI-IEQR6ZU-CGWRWQT";
      };
      folders = {
        Music = {
          path = "/home/${username}/Music";
          devices = [ "phone" ];
        };
      };
    };
  };

  programs.hyprland = {
    enable = true;
    withUWSM = true;
  };

  # Add flatpak support
  services.flatpak.enable = true;
}
