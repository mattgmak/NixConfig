{
  flake.homeModules.git =
    { hostname, ... }:
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
          submodule.recurse = true;
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
    };
}
