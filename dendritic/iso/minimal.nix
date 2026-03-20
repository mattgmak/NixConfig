{
  inputs,
  self,
  withSystem,
  ...
}:
{
  flake.nixosConfigurations.minimalIso = withSystem "x86_64-linux" (
    {
      inputs',
      ...
    }:
    inputs.nixpkgs.lib.nixosSystem {
      specialArgs = {
        inherit inputs inputs';
        username = "nixos";
        hostname = self.constants.serverName;
      };
      modules = [
        inputs.home-manager.nixosModules.home-manager
        self.nixpkgsConfig
        self.nixConfig
        self.nixosModules.minimalIso
      ];
    }
  );

  # nix build .#nixosConfigurations.minimalIso.config.system.build.isoImage
  flake.nixosModules.minimalIso =
    {
      pkgs,
      modulesPath,
      hostname,
      username,
      ...
    }:
    {
      imports = [
        "${modulesPath}/installer/cd-dvd/installation-cd-minimal.nix"
      ];
      nixpkgs.hostPlatform = "x86_64-linux";

      home-manager = {
        useGlobalPkgs = true;
        useUserPackages = true;
        extraSpecialArgs = {
          inherit
            username
            hostname
            ;
        };
        backupFileExtension = "hm-backup-1";
      };

      home-manager.users.${username} = self.homeConfigurations.minimalIso;

      environment.shells = with pkgs; [
        nushell
        bash
      ];

      # Set your time zone.
      time.timeZone = "Asia/Hong_Kong";

      # Select internationalisation properties.
      i18n.defaultLocale = "en_HK.UTF-8";

      # Define a user account. Don't forget to set a password with 'passwd'.
      users.users.${username} = {
        isNormalUser = true;
        extraGroups = [
          "networkmanager"
          "wheel"
          "input"
          "kvm"
          "dialout"
        ];
        shell = pkgs.nushell;
        openssh.authorizedKeys.keys = with self.sshKeys; [
          GoofyDesky
          GoofyEnvy
          Droid
        ];
      };

      services.openssh.enable = true;
      security.sudo = {
        enable = true;
        wheelNeedsPassword = false;
      };
      networking.hostName = hostname;
      networking.networkmanager = {
        enable = true;
        plugins = with pkgs; [ networkmanager-openvpn ];
      };

      environment.systemPackages = with pkgs; [
        fzf
        ripgrep
        zip
        unzip
        nh
        nvd
        nix-output-monitor
        neofetch
        nitch
        zenity
        gh
        dua
        parted
        tparted
      ];
    };

  flake.homeConfigurations.minimalIso = {
    imports = with self.homeModules; [
      nixos-home
      atuin
      zoxide
      nushell
      neovim
      starship
      yazi
      git
      direnv
      lazygit
      carapace
    ];
  };

}
