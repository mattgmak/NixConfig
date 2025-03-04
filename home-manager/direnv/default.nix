{
  programs = {
    direnv = {
      enable = true;
      enableNushellIntegration = true;
      enableBashIntegration = true;
      nix-direnv.enable = true;
    };
  };
  home.file = { "test/.envrc".source = ./test/.envrc; };
}
