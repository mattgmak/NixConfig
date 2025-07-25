{ hostname, ... }: {
  programs.git = {
    enable = true;
    delta = { enable = true; };
    userName = "mattgmak";
    userEmail = "u3592095@connect.hku.hk";
    extraConfig = {
      fetch.prune = true;
      rerere.enabled = true;
      # 7 days
      # credential.helper = [ "cache --timeout 604800" "oauth" ];
      credential = {
        helper = [ "manager" ];
        "https://github.com".username = "mattgmak";
        credentialStore = "cache";
        cacheOptions = "--timeout 604800";
      };
    } // (if hostname == "GoofyWSL" then {
      credential.helper =
        "/mnt/c/Program\\ Files/Git/mingw64/bin/git-credential-manager.exe";
    } else
      { });
  };
}
