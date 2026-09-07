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
      { lib, username, ... }:
      {
        imports = [ self.homeModules.main ];
        home = {
          inherit username;
          homeDirectory = "/Users/${username}";
        };

        # agenix's age-home.nix sets KeepAlive with SuccessfulExit=false,
        # but macOS MinimumRuntime (default 10s) overrides it — any exit
        # before 10s is treated as crash, so the agent respawns forever.
        # MinimumRuntime takes integer seconds only, can't go below 1
        # (script runs ~704ms).  Simplest fix: disable KeepAlive entirely.
        # RunAtLoad=true runs the agent once at login; no KeepAlive means
        # launchd never respawns.
        launchd.agents.activate-agenix.config.KeepAlive = lib.mkForce false;
      };
  };
}