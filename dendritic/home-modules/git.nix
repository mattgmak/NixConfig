{
  flake.homeModules.git =
    { hostname, ... }:
    {
      programs.git = {
        enable = true;
        settings = {
          user = {
            name = "mattgmak";
            email = "u3592095@connect.hku.hk";
          };
          fetch.prune = true;
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
