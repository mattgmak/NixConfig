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

    homeModules.nixos-home =
      {
        # home.username + home.homeDirectory are auto-set per user by
        # home-manager's NixOS/darwin integration:
        #   home.username     = users.users.<name>.name
        #   home.homeDirectory = users.users.<name>.home
        # NixOS sets users.users.root.home = "/root" and others /home/<name>,
        # so repeated NixOS deployments (root + agent + desktop) derive the
        # correct path per user without reading the host-global `username`
        # specialArg (which is "root" on Goofeus for BOTH users).
        ...
      }:
      {
        imports = [ self.homeModules.main ];
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
