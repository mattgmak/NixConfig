{ hostname, ... }: {
  programs.git = {
    enable = true;
    delta = { enable = true; };
    userName = "mattgmak";
    userEmail = "u3592095@connect.hku.hk";
    extraConfig = {
      fetch.prune = true;
      rerere.enabled = true;
    } // (if hostname == "GoofyWSL" then {
      credential.helper =
        "/mnt/c/Program\\ Files/Git/mingw64/bin/git-credential-manager.exe";
    } else
      { });
  };
}
