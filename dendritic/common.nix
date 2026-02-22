{ inputs, self, ... }:
{
  flake.nixosModules.common =
    {
      pkgs,
      hostname,
      username,
      pkgs-for-cursor,
      pkgs-stable,
      config,
      lib,
      ...
    }:
    {
      imports = [
        self.fonts
        self.stylixCommon
        self.stylixCursor
        inputs.home-manager.nixosModules.home-manager
        inputs.stylix.nixosModules.stylix
        self.nixpkgsConfig
        self.nixConfig
        self.nixosModules.syncthing
      ];
      home-manager = {
        useGlobalPkgs = true;
        useUserPackages = true;
        extraSpecialArgs = {
          inherit
            hostname
            username
            pkgs-for-cursor
            pkgs-stable
            ;
        };
        backupFileExtension = "hm-backup-1";
      };

      # Enable networking
      networking.hostName = hostname;
      networking.networkmanager = {
        enable = true;
        plugins = with pkgs; [ networkmanager-openvpn ];
      };
      networking.firewall = {
        enable = true;
        allowedTCPPorts = [
          80
          443
          3000
          8081
          8082
          3210
        ];
        allowedUDPPorts = [
          80
          443
          3210
        ];
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
      environment.shells = with pkgs; [
        nushell
        bash
      ];

      systemd.services.fprintd = {
        wantedBy = [ "multi-user.target" ];
        serviceConfig.Type = "simple";
      };
      services.fprintd = {
        enable = true;
      };

      security.polkit.enable = true;
      security.pam.services.gdm-fingerprint = lib.mkIf (config.services.fprintd.enable) {
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
        # greetd.enableGnomeKeyring = true;
        # greetd-password.enableGnomeKeyring = true;
        login = {
          fprintAuth = false;
          enableGnomeKeyring = true;
        };
        gdm.enableGnomeKeyring = true;
        gdm-password.enableGnomeKeyring = true;
        hyprlock.enableGnomeKeyring = true;
      };
      services.dbus.packages = with pkgs; [
        gnome-keyring
        gcr
      ];

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
        extraGroups = [
          "networkmanager"
          "wheel"
          "adbusers"
          "input"
          "kvm"
          "dialout"
        ];
        shell = pkgs.nushell;
      };

      security.sudo.enable = true;

      environment.systemPackages = with pkgs; [
        wget
        git
        chezmoi
        appimage-run
        nushell
        fzf
        zoxide
        starship
        ripgrep
        zip
        unzip
        nixfmt
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
        stylua
        inputs.wiremix.packages.${pkgs.stdenv.hostPlatform.system}.wiremix
        ffmpeg-full
        uwsm
        kdePackages.kdeconnect-kde
        qimgv
        pdfarranger
        paprefs
        pulseaudio-ctl
        croc
        devbox
        go
      ];

      programs.dconf.enable = true;

      programs.hyprland = {
        enable = true;
        withUWSM = true;
        package = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
        portalPackage =
          inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.xdg-desktop-portal-hyprland;
      };

      programs.nix-ld = {
        enable = true;
        # libraries = with pkgs; [ ];
      };

      virtualisation.docker = {
        enable = true;
      };
      # Add flatpak support
      services.flatpak.enable = true;
    };

}
