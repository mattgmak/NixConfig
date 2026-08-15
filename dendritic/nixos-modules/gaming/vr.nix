{
  flake.nixosModules.vr =
    { mv, ... }:
    {
      services.wivrn = {
        enable = true;
        openFirewall = true;
        autoStart = true;
        package = mv.vr.wivrn;
      };

      environment.systemPackages = with mv.vr; [
        bs-manager
        sidequest
      ];
    };
}
