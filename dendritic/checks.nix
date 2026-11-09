# Flake checks for every host config, plus the Ramsay boot test.
#
#   nix flake check --no-build                      eval every host, build nothing
#   nix build .#checks.x86_64-linux.Ramsay          build the system toplevel
#   nix build .#checks.x86_64-linux.Ramsay-vm       build the QEMU image
#   nix build .#checks.x86_64-linux.Ramsay-test     boot the VM and run the test
#
# Add an entry here whenever you add a file under dendritic/hosts/.
{ lib, inputs, self, ... }:
{
  perSystem =
    { config, inputs', pkgs, self', system, ... }:
    let
      nixosSystems = {
        Ramsay = "x86_64-linux";
        Goofeus = "x86_64-linux";
        GoofyDesky = "x86_64-linux";
        GoofyEnvy = "x86_64-linux";
      };
      darwinSystems = {
        MacMini = "aarch64-darwin";
      };

      localNixos = lib.filterAttrs (_: s: s == system) nixosSystems;
      localDarwin = lib.filterAttrs (_: s: s == system) darwinSystems;

      # Eval and build tiers: the system each host resolves to on this platform.
      toplevels =
        lib.mapAttrs'
          (name: _: lib.nameValuePair name self.nixosConfigurations.${name}.config.system.build.toplevel)
          localNixos
        // lib.mapAttrs'
          (name: _: lib.nameValuePair name self.darwinConfigurations.${name}.system)
          localDarwin;

      # VM image tier: the image each NixOS host boots.
      vms = lib.mapAttrs'
        (name: _: lib.nameValuePair "${name}-vm" self.nixosConfigurations.${name}.config.system.build.vm)
        localNixos;

      # Boot tier. A VM has no disko layout and no Strix Halo hardware module,
      # so the node takes the software modules only. The real system keeps its
      # disk and hardware modules in dendritic/hosts/Ramsay.nix.
      ramsayTest = pkgs.testers.runNixOSTest {
        name = "nixos-Ramsay-test";
        # The test-level `node` group holds the module arguments; the test driver
        # reads them from there and passes them to every node's eval.
        node.pkgsReadOnly = false;
        node.specialArgs = {
          inherit inputs inputs' self';
          inherit (config) packages common-overlays common-nixpkgs-config;
          username = "root";
          hostname = self.constants.ramsayName;
        };
        nodes.machine = {
          imports =
            with self.nixosModules;
            [
              Ramsay
              caTrust
              tailscale
              gufo
              inference
              hermes
            ]
            ++ [
              self.stylixCommon
              self.nixConfig
              inputs.agenix.nixosModules.default
              inputs.home-manager.nixosModules.home-manager
              inputs.stylix.nixosModules.stylix
            ];
          virtualisation.graphics = false;
          virtualisation.memorySize = 2048;
        };
        # agenix cannot decrypt the real secrets without the host key, so the
        # test checks ssh and the system link instead of multi-user.target.
        testScript = # python
          ''
            machine.start()
            machine.wait_for_unit("ssh.service")
            machine.wait_for_open_port(22)
            machine.succeed("test -e /run/current-system")
            machine.succeed("systemctl cat halogen-dashboard.service > /dev/null")
          '';
      };

      bootTests = lib.optionalAttrs (system == "x86_64-linux") {
        "Ramsay-test" = ramsayTest;
      };
    in
    {
      checks = toplevels // vms // bootTests;
    };
}
