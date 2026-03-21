{ inputs, self, ... }:
{
  imports = [ inputs.home-manager.flakeModules.home-manager ];
  flake = {
    homeModules.main = {
      home.stateVersion = "24.11"; # Please read the comment before changing.
      programs.home-manager.enable = true;
    };

    # TODO: refactor this
    homeModules.nixos-home =
      { username, ... }:
      {
        imports = [ self.homeModules.main ];
        home = {
          inherit username;
          # Must match NixOS/home-manager default for root (/root), not /home/root.
          homeDirectory = if username == "root" then "/root" else "/home/${username}";
        };
      };

    homeModules.darwin-home =
      { username, ... }:
      {
        imports = [ self.homeModules.main ];
        home = {
          inherit username;
          homeDirectory = "/Users/${username}";
        };
      };
  };
}
