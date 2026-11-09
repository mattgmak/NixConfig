{ moduleWithSystem, ... }:
{
  flake.nixosModules.vr = moduleWithSystem (
    perSystem@{ self' }:
    { ... }:
    let
      mv = perSystem.self'.legacyPackages.mv;
    in
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
    }
  );
}
