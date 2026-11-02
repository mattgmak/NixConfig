{
  flake.homeModules.git =
    {
      hostname,
      lib,
      pkgs,
      ...
    }:
    {
      programs.git = {
        enable = true;
        signing.format = null;
        settings = {
          user = {
            name = "mattgmak";
            email = "u3592095@connect.hku.hk";
          };
          fetch.prune = true;
          fetch.recurseSubmodules = "on-demand";
          clone.recurseSubmodules = true;
          # Goofeus: nix flake metadata --refresh fans out many submodule ls-remote
          # calls; serialise fetches and prefer HTTP/1.1 under burst load.
          # Do NOT set http.lowSpeed* here — it aborts large ls-remote bodies (e.g. nixpkgs).
          fetch.parallel = if hostname == "Goofeus" then 1 else 8;
          http.version = if hostname == "Goofeus" then "HTTP/1.1" else "HTTP/2";
          rerere.enabled = true;
          core.ignorecase = false;
          # 7 days
          # credential.helper = [ "cache --timeout 604800" "oauth" ];
          # credential = {
          # helper = "manager";
          # "https://github.com".username = "mattgmak";
          # credentialStore = "cache";
          # cacheOptions = "--timeout 604800";
          # };
          push.recurseSubmodules = "on-demand";
          # Pull must not block on submodules. githooks/post-merge refreshes them in background.
          submodule.recurse = false;
          # Clone new vendor submodules on pull/ff without manual --init.
          submodule.autoInit = true;
        }
        // (
          if hostname == "GoofyWSL" then
            {
              credential.helper = "/mnt/c/Program\\ Files/Git/mingw64/bin/git-credential-manager.exe";
            }
          else
            { }
        );
      };

      # githooks/post-merge and post-checkout refresh vendor submodules. A pull
      # that records a new submodule leaves an empty dir, and Nix then fails
      # with "Failed to fetch git repository". The path is repo-local, so set it
      # for every host that keeps the repo in ~/NixConfig.
      home.activation.nixConfigHooks =
        lib.hm.dag.entryAfter [ "writeBoundary" ]
          ''
            if [ -d "$HOME/NixConfig/.git" ]; then
              ${lib.getExe pkgs.git} -C "$HOME/NixConfig" config --local core.hooksPath githooks || true
            fi
          '';
    };
}
