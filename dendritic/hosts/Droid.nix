{ self, ... }:
{
  flake.nixOnDroidConfiguration =
    { config, pkgs, ... }:
    {
      # Simply install just the packages
      environment.packages = with pkgs; [
        # User-facing stuff that you really really want to have
        neovim # or some other editor, e.g. nano or neovim
        git
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
      ];

      home-manager.config = {
        imports = with self.homeModules; [
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
        ];
        home = {
          stateVersion = "24.05";
        };
      };

      home-manager = {
        useGlobalPkgs = true;
        useUserPackages = true;
        extraSpecialArgs = {
          inherit (self.constants) username;
          hostname = "droid";
        };
        backupFileExtension = "hm-backup-1";
      };

      user.username = self.constants.username;
      user.shell = "${pkgs.nushell}/bin/nu";

      # Backup etc files instead of failing to activate generation if a file already exists in /etc
      environment.etcBackupExtension = ".bak";

      # Read the changelog before changing this value
      system.stateVersion = "24.05";

      # Set up nix for flakes
      nix.extraOptions = ''
        experimental-features = nix-command flakes
      '';

      terminal.font = "${pkgs.nerd-fonts.iosevka-term}/share/fonts/truetype/IosevkaTermNerdFontMono-Regular.ttf";
      # Set your time zone
      time.timeZone = "Asia/Hong_Kong";
    };
}
