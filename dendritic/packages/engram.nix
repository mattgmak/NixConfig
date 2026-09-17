{ inputs, ... }:
{
  perSystem =
    { pkgs, ... }:
    let
      engram = pkgs.callPackage (
        {
          lib,
          stdenv,
          fetchurl,
          gnutar,
        }:

        let
          # Keep in sync with gentle-engram ext (vendor/Gentleman-Programming/engram
          # plugin/pi). Stable 1.20.0 lacks the `instance-id` subcommand + /health
          # instance_id field that the rc-era plugin requires for server identity;
          # rc bin is the floor per ref.md (bump procedure).
          version = "2.0.0-rc.11";
          baseUrl = "https://github.com/Gentleman-Programming/engram/releases/download/v${version}";

          platformAttrs = {
            "x86_64-linux" = {
              asset = "linux_amd64";
              hash = "sha256-Ez4NBmSSOnAAWqlhlh/ovBtOsT1Zr7WAEMbL3oF4agY=";
            };
            "aarch64-linux" = {
              asset = "linux_arm64";
              hash = "sha256-poSUtDc9g5pkjTv1j/y17ldPOL+C5Oy8BEfRBeIt0D4=";
            };
            "aarch64-darwin" = {
              asset = "darwin_arm64";
              hash = "sha256-60+ogGx/18RJe8j6Sgwo/N2uobzwH8+gMTl1wgolENU=";
            };
            "x86_64-darwin" = {
              asset = "darwin_amd64";
              hash = "sha256-glmdrYa5ubN4hqVT9Vp8oNjqmcJVgxp2N7xHRpIkpmk=";
            };
          };

          attrs =
            platformAttrs.${stdenv.hostPlatform.system}
              or (throw "engram: unsupported platform ${stdenv.hostPlatform.system}");
        in
        stdenv.mkDerivation {
          pname = "engram";
          inherit version;

          src = fetchurl {
            url = "${baseUrl}/engram_${version}_${attrs.asset}.tar.gz";
            hash = attrs.hash;
          };

          # Release archives are flat (binary + docs at archive root).
          dontUnpack = true;

          nativeBuildInputs = [ gnutar ];

          installPhase = ''
            runHook preInstall
            mkdir -p $out/bin
            ${lib.getExe gnutar} -xOf $src engram > $out/bin/engram
            chmod +x $out/bin/engram
            runHook postInstall
          '';

          doCheck = false;
          doInstallCheck = true;
          installCheckPhase = ''
            $out/bin/engram version | grep -F "${version}"
          '';

          meta = with lib; {
            description = "Persistent memory for AI coding agents";
            homepage = "https://github.com/Gentleman-Programming/engram";
            license = licenses.mit;
            sourceProvenance = with sourceTypes; [ binaryNativeCode ];
            platforms = builtins.attrNames platformAttrs;
            mainProgram = "engram";
          };
        }
      ) { };
    in
    {
      packages.engram = engram;
    };
}
