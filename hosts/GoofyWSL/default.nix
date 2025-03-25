{ inputs, pkgs, system, ... }: {
  imports = [ ../common.nix inputs.nixos-wsl.nixosModules.default ];
  wsl = {
    enable = true;
    defaultUser = "goofy";
  };
  programs.nix-ld = {
    enable = true;
    package = pkgs.nix-ld-rs;
  };
  environment.systemPackages =
    [ inputs.my-code-cursor.packages.${system}.default ];

  system.stateVersion = "24.11";
}
