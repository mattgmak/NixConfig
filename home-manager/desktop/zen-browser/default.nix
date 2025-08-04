{ inputs, ... }: {
  # imports = [ inputs.zen-browser.homeModules.beta ];
  # programs.zen-browser = {
  #   enable = true;
  #   policies = {
  #     Preferences = let
  #       locked = value: {
  #         "Value" = value;
  #         "Status" = "locked";
  #       };
  #     in { "nebula-tab-switch-animation" = locked 4; };
  #   };
  # };

  home.file.".zen/GoofyZen/chrome" = {
    source = ./chrome;
    recursive = true;
  };
}
