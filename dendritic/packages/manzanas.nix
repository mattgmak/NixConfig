{
  inputs,
  self,
  ...
}:
{
  perSystem =
    { pkgs, ... }:
    let
      manzanas = pkgs.callPackage (
        {
          lib,
          stdenvNoCC,
          fetchurl,
        }:
        stdenvNoCC.mkDerivation (finalAttrs: {
          pname = "manzanas";
          version = "0.7.0";

          # Release binaries ship manzanasd, manzanas and manzanas-broker.
          # The npm wrapper downloads these same files at install time, which
          # no sandbox build can do, so take them from the release instead.
          src = fetchurl {
            url = "https://github.com/BariBariGood/manzanas/releases/download/v${finalAttrs.version}/manzanasd_${finalAttrs.version}_darwin_arm64.tar.gz";
            hash = "sha256-MtmMnRpTSHzgYL+UWmTDroxiI8GFsAFq5t8pPYD9sf8=";
          };

          dontConfigure = true;
          dontBuild = true;
          # Prebuilt Mach-O, not build output: leave the binaries alone.
          dontFixup = true;

          unpackPhase = ''
            tar -xzf "$src"
          '';
          sourceRoot = ".";

          installPhase = ''
            runHook preInstall
            install -d "$out/bin"
            install -m 0755 manzanas manzanasd manzanas-broker "$out/bin/"
            install -d "$out/share/manzanas"
            install -m 0644 LICENSE NOTICE "$out/share/manzanas/"
            runHook postInstall
          '';

          meta = {
            description = "Mac daemon for multi-agent iOS simulator fleet orchestration";
            homepage = "https://github.com/BariBariGood/manzanas";
            license = lib.licenses.asl20;
            sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
            mainProgram = "manzanasd";
            platforms = [ "aarch64-darwin" ];
          };
        })
      ) { };
    in
    {
      packages.manzanas = manzanas;
    };
}
