{ inputs, self, ... }:
{
  imports = [ inputs.home-manager.flakeModules.home-manager ];
  flake = {
    homeModules.main = {
      home.stateVersion = "26.05"; # Please read the comment before changing.
      programs.home-manager.enable = true;

      # Skip installing the HM reference manpage. Its drv embeds
      # `${hmOptionsDocs.optionsJSON}/share/doc/nixos/options.json`
      # (nixosOptionsDoc = runCommand "options.json" with
      # unsafeDiscardStringContext'd module paths), so merely forcing its
      # outPath during the per-user profile buildEnv eval emits the
      # "references the store path ... without a proper context" warning.
      # manual.manpages.enable = false;
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
