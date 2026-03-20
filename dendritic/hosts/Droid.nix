{ self, inputs, ... }:
{
  flake.nixOnDroidConfiguration =
    { config, pkgs, ... }:
    {
      imports = [ inputs.stylix.nixOnDroidModules.stylix ];

      stylix = {
        overlays.enable = false;
        # enable = true;
      };
      # Simply install just the packages
      environment.packages = with pkgs; [
        # User-facing stuff that you really really want to have
        # neovim # or some other editor, e.g. nano or neovim
        # git
        # Some common stuff that people expect to have
        procps
        killall
        diffutils
        findutils
        utillinux
        tzdata
        hostname
        man
        gnugrep
        gnupg
        gnused
        gnutar
        bzip2
        gzip
        xz
        zip
        unzip
        which
        openssh
        curlMinimal
        busybox
        cursor-cli
        dnsutils
      ];

      home-manager.config = {
        imports = with self.homeModules; [
          atuin
          zoxide
          nushell
          neovim
          starship
          yazi
          git
          delta
          gh
          direnv
          lazygit
          carapace
          tmux
          nix-index-database
          opencode
        ];
        programs.ssh = {
          enable = true;
        };
        home = {
          stateVersion = "24.05";
        };
      };

      home-manager = {
        useGlobalPkgs = true;
        useUserPackages = true;
        extraSpecialArgs = {
          inherit (self.constants) username;
          hostname = "Droid";
        };
        backupFileExtension = "hm-backup-1";
      };

      # user.userName = self.constants.username;
      user.shell = "${pkgs.nushell}/bin/nu";

      # Backup etc files instead of failing to activate generation if a file already exists in /etc
      environment.etcBackupExtension = ".bak";

      # Read the changelog before changing this value
      system.stateVersion = "24.05";

      # Set up nix for flakes
      nix.extraOptions = ''
        experimental-features = nix-command flakes
      '';
      nix = {
        substituters = [
          "https://yazi.cachix.org"
        ];
        trustedPublicKeys = [
          "yazi.cachix.org-1:Dcdz63NZKfvUCbDGngQDAZq6kOroIrFoyO064uvLh8k="
        ];
      };

      terminal.font = "${pkgs.nerd-fonts.iosevka-term}/share/fonts/truetype/NerdFonts/IosevkaTerm/IosevkaTermNerdFontMono-Regular.ttf";
      # Set your time zone
      time.timeZone = "Asia/Hong_Kong";
    };
}
