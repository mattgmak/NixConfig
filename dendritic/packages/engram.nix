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
          # Keep in sync with the vendored plugin/pi companion
          # (vendor/Gentleman-Programming/engram). Upstream pairs each core
          # release with one companion version.
          version = "3.7.2";
          baseUrl = "https://github.com/Gentleman-Programming/engram/releases/download/v${version}";

          platformAttrs = {
            "x86_64-linux" = {
              asset = "linux_amd64";
              hash = "sha256-jbnV2xwVdLi4MKrE/76GwCQBSu1rmj8EBqwzYaFSzfA=";
            };
            "aarch64-linux" = {
              asset = "linux_arm64";
              hash = "sha256-zbvLaNPoQtPlLiftzO9V5v6YzjzbyQzXmJQyOwKe+1A=";
            };
            "aarch64-darwin" = {
              asset = "darwin_arm64";
              hash = "sha256-+W4I249HyknrwDTrow5GjbgetW35j5vyGnM2a1EGleQ=";
            };
            "x86_64-darwin" = {
              asset = "darwin_amd64";
              hash = "sha256-01YjRDpdhej3gzjNpdC7c7L37GIXpX5Ku3GQSj4NYoc=";
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
