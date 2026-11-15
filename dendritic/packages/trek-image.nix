# OCI image for TREK — built from pinned inputs.trek-src.
# The image is built on the host via systemd (podman cannot run in the Nix sandbox).
# Manual build: nix run .#packages.x86_64-linux.trek-image
{ inputs, ... }:
{
  perSystem =
    { pkgs, ... }:
    let
      trekSrc = inputs.trek-src;
      trekRev = builtins.substring 0 7 trekSrc.rev;
      # The Dockerfile writes APP_VERSION into /app/server/VERSION, and the server reads
      # that file, so the build has to pass the real release number instead of a dev tag.
      version = (builtins.fromJSON (builtins.readFile (trekSrc + "/package.json"))).version;
      imageName = "trek";
      imageTag = "v${version}-${trekRev}";
      fullName = "${imageName}:${imageTag}";

      buildScript = pkgs.writeShellApplication {
        name = "trek-image-build";
        runtimeInputs = [ pkgs.podman ];
        text = ''
          set -euo pipefail

          export HOME="''${STATE_DIRECTORY:-/var/lib/trek-image-build}"
          mkdir -p "$HOME/.local/share/containers/storage" "$HOME/.config"

          if podman image exists ${fullName} 2>/dev/null; then
            echo "TREK image ${fullName} already present"
            exit 0
          fi

          echo "Building TREK image ${fullName} from ${trekSrc}..."
          cd ${trekSrc}
          podman build \
            --isolation=chroot \
            --network=host \
            --build-arg APP_VERSION=${version} \
            -t ${fullName} \
            -f Dockerfile .

          echo "Built ${fullName}"
        '';
      };
    in
    {
      packages.trek-image =
        pkgs.runCommand "trek-image-${imageTag}" { } ''
          mkdir -p $out/bin
          ln -s ${buildScript}/bin/trek-image-build $out/bin/trek-image-build
        ''
        // {
          passthru = {
            inherit imageName imageTag fullName;
            buildScript = "${buildScript}/bin/trek-image-build";
          };
        };
    };
}
