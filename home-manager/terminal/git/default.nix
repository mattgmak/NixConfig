{ hostname, ... }: {
  programs.git = {
    enable = true;
    userName = "mattgmak";
    userEmail = "u3592095@connect.hku.hk";
    extraConfig = {
      fetch.prune = true;

      # Set credential helper conditionally based on hostname
      credential.helper = if hostname == "GoofyWSL" then
        "/mnt/c/Program\\ Files/Git/mingw64/bin/git-credential-manager.exe"
      else
        null;
    };
  };
}
