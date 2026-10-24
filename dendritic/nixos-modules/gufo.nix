# gufo: Strix Halo (gfx1151) inference engine. Upstream ships no NixOS module,
# so this file only provides the package and the host prerequisites.
{ inputs, ... }:
{
  flake.nixosModules.gufo =
    { pkgs, ... }:
    {
      nixpkgs.overlays = [
        (final: _prev: {
          gufo = inputs.gufo.packages.${final.stdenv.hostPlatform.system}.default;
        })
      ];

      # Gufo maps /dev/kfd and /dev/dri/renderD* through its own ROCm runtime.
      hardware.graphics.enable = true;

      # Gufo pins weight pages with mlock. The default 64 KiB limit aborts the load.
      security.pam.loginLimits = [
        {
          domain = "*";
          item = "memlock";
          value = "unlimited";
        }
      ];

      # No packaged rule covers kfd. Without it the node stays root-only.
      services.udev.extraRules = ''
        KERNEL=="kfd", GROUP="render", MODE="0660"
      '';
    };
}
