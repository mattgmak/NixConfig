{ pkgs, ... }: {
  services.hyprsunset = {
    enable = true;
    package = pkgs.hyprsunset;
    transitions = {
      night = {
        calendar = "*-*-* 18:00:00";
        requests = [[ "temperature" "5000" ]];
      };
      morning = {
        calendar = "*-*-* 06:00:00";
        requests = [[ "temperature" "6000" ]];
      };
    };
  };
}
