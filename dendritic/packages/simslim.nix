{
  inputs,
  self,
  ...
}:
{
  perSystem =
    { pkgs, ... }:
    let
      simslim = pkgs.callPackage (
        {
          lib,
          stdenvNoCC,
          fetchurl,
        }:
        stdenvNoCC.mkDerivation (finalAttrs: {
          pname = "simslim";
          version = "0.13.0";

          # Go binary from goreleaser. Nixpkgs has no package and the Homebrew
          # formula builds the same asset.
          src = fetchurl {
            url = "https://github.com/MobAI-App/simslim/releases/download/v${finalAttrs.version}/simslim-v${finalAttrs.version}-macos-arm64.tar.gz";
            hash = "sha256-doB++1vrV7c7QJWe6gTe/iH8GCZYEaSV2xUJtee+B8E=";
          };

          dontConfigure = true;
          dontBuild = true;
          # Signed Mach-O: keep the signature so simctl calls stay trusted.
          dontFixup = true;

          sourceRoot = ".";

          installPhase = ''
            runHook preInstall
            install -d "$out/bin"
            install -m 0755 simslim "$out/bin/simslim"
            runHook postInstall
          '';

          meta = {
            description = "Cut iOS simulator background services to fit more simulators per Mac";
            homepage = "https://github.com/MobAI-App/simslim";
            license = lib.licenses.mit;
            sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
            mainProgram = "simslim";
            platforms = [ "aarch64-darwin" ];
          };
        })
      ) { };
    in
    {
      packages.simslim = simslim;
    };
}
