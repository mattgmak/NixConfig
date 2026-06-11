# OCI image for TREK — built from pinned inputs.trek-src (dev branch).
# Build: nix build .#packages.x86_64-linux.trek-image
# May need: --option sandbox false (podman build runs npm ci inside Dockerfile)
{
  inputs,
  pkgs,
  lib,
  ...
}:
let
  trekRev = builtins.substring 0 7 inputs.trek-src.rev;
  imageName = "trek";
  imageTag = "dev-${trekRev}";
in
{
  packages.trek-image =
    pkgs.runCommand "trek-image-${imageTag}"
      {
        nativeBuildInputs = [ pkgs.podman ];
        preferLocalBuild = true;
        allowSubstitutes = false;
        passthru = {
          inherit imageName imageTag;
          fullName = "${imageName}:${imageTag}";
        };
      }
      ''
        export HOME=$TMPDIR
        mkdir -p $HOME/.local/share/containers/storage $HOME/.config

        cd ${inputs.trek-src}
        ${pkgs.podman}/bin/podman build \
          --isolation=chroot \
          --network=host \
          --build-arg APP_VERSION=${imageTag} \
          -t ${imageName}:${imageTag} \
          -f Dockerfile .

        mkdir -p $out
        ${pkgs.podman}/bin/podman save -o $out/image.tar ${imageName}:${imageTag}
      '';
}
