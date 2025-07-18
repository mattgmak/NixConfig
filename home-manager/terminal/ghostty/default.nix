{ ... }:
let
in {
  programs.ghostty = {
    enable = true;
    settings = {
      font-size = 14;
      font-family = "IosevkaTerm Nerd Font";
    };
  };
}
