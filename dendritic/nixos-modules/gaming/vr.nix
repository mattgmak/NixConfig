{
  flake.nixosModules.vr = { pkgs, ... }: {
    services.wivrn = {
      enable = true;
      openFirewall = true;
      defaultRuntime = true;
      autoStart = true;
    };

    environment.systemPackages = with pkgs; [ bs-manager sidequest ];
  };
}
