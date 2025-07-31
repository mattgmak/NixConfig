{ ... }: {
  # services.hyprsunset = {
  #   enable = true;
  #   package = pkgs.hyprsunset;
  #   transitions = {
  #     night = {
  #       calendar = "*-*-* 18:00:00";
  #       requests = [[ "temperature" "5000" ]];
  #     };
  #     morning = {
  #       calendar = "*-*-* 06:00:00";
  #       requests = [[ "temperature" "6000" ]];
  #     };
  #   };
  # };
  home.file.".config/hypr/hyprsunset.conf".text = ''
    profile {
      time = 6:30
      identity = true
    }

    profile {
      time = 18:30
      temperature = 5000
    }
  '';
}
