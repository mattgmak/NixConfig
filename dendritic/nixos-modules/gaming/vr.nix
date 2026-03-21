{
  flake.nixosModules.vr =
    { pkgs-for-vr, ... }:
    {
      services.wivrn = {
        enable = true;
        openFirewall = true;
        defaultRuntime = true;
        autoStart = true;
        package = pkgs-for-vr.wivrn;
      };

      environment.systemPackages = with pkgs-for-vr; [
        bs-manager
        sidequest
      ];
    };
}
