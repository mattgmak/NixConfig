{ inputs, pkgs, ... }: {
  imports = [ ../common.nix inputs.nixos-wsl.nixosModules.default ];
  wsl = {
    enable = true;
    defaultUser = "goofy";
  };
  programs.nix-ld = {
    enable = true;
    package = pkgs.nix-ld-rs;
  };
  environment.systemPackages = with pkgs; [ ];

  system.stateVersion = "24.11";
}
