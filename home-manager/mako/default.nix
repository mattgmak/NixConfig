# https://github.com/emersion/mako
{
  services.mako = {
    enable = true;
    anchor = "top-right";
    borderRadius = 2;
    borderSize = 2;
    font = "IosevkaTerm Nerd Font";
    icons = true;
    extraConfig = builtins.readFile ./config;
  };
}
