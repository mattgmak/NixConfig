{
  inputs,
  self,
  ...
}:
{
  perSystem =
    { pkgs, ... }:
    let
      hostPlatform = pkgs.stdenv.hostPlatform;
      axe = self.packages.${hostPlatform.system}.axe;

      # Release assets are named GOOS_GOARCH. The client is a thin Go binary,
      # so Linux hosts reach the daemon on a Mac over the network.
      releaseHashes = {
        aarch64-darwin = "sha256-MtmMnRpTSHzgYL+UWmTDroxiI8GFsAFq5t8pPYD9sf8=";
        x86_64-darwin = "sha256-oypzbUCtVwT22825mESttKmoj1R4JAiGpm4BRxkAYeg=";
        x86_64-linux = "sha256-Rv+v0fv0H0WI7NMFV7RI1Zp5MCzxOHgdG5HFszs5p2A=";
        aarch64-linux = "sha256-OMvEJCWEIYKzTpR+0qoRDCxWsmS/rhyTtoKBy8WDaUw=";
      };
      # The daemon loads this helper for warm actions. Upstream publishes it for
      # darwin-arm64 only, so other hosts fall back to cold AXe actions.
      simbridgeHash = "sha256-YlRW+jKjLoMZp9cyjPQg70NIjMw48W14SKIM2x131Ao=";
      manzanasVersion = "0.7.0";
      wrapSimbridge = hostPlatform.isDarwin && hostPlatform.isAarch64;
      simbridgeAsset =
        if wrapSimbridge then
          pkgs.fetchurl {
            url = "https://github.com/BariBariGood/manzanas/releases/download/v${manzanasVersion}/simbridge_${manzanasVersion}_darwin_arm64";
            hash = simbridgeHash;
          }
        else
          null;

      manzanas = pkgs.callPackage (
        {
          lib,
          stdenvNoCC,
          fetchurl,
          makeWrapper,
        }:
        stdenvNoCC.mkDerivation (finalAttrs: {
          pname = "manzanas";
          version = manzanasVersion;

          # Release binaries ship manzanasd, manzanas and manzanas-broker.
          # The npm wrapper downloads these same files at install time, which
          # no sandbox build can do, so take them from the release instead.
          src = fetchurl {
            url = "https://github.com/BariBariGood/manzanas/releases/download/v${finalAttrs.version}/manzanasd_${finalAttrs.version}_${hostPlatform.go.GOOS}_${hostPlatform.go.GOARCH}.tar.gz";
            hash = releaseHashes.${hostPlatform.system};
          };

          dontConfigure = true;
          dontBuild = true;
          # Prebuilt Go and Mach-O binaries, not build output: leave them alone.
          dontFixup = true;

          unpackPhase = ''
            tar -xzf "$src"
          '';
          sourceRoot = ".";

          nativeBuildInputs = [ makeWrapper ];

          installPhase = ''
            runHook preInstall
            install -d "$out/bin"
            install -m 0755 manzanas manzanasd manzanas-broker "$out/bin/"
            install -d "$out/share/manzanas"
            install -m 0644 LICENSE NOTICE "$out/share/manzanas/"
          ''
          + lib.optionalString wrapSimbridge ''
            install -d "$out/libexec"
            install -m 0755 ${simbridgeAsset} "$out/libexec/simbridge"
            # The release links FBSimulatorControl through an rpath of the CI
            # build host, so the AXe frameworks must come from the environment.
            makeWrapper "$out/libexec/simbridge" "$out/bin/simbridge" \
              --prefix DYLD_FRAMEWORK_PATH : ${axe}/libexec/axe/Frameworks
          ''
          + ''
            runHook postInstall
          '';

          meta = {
            description = "Mac daemon for multi-agent iOS simulator fleet orchestration";
            homepage = "https://github.com/BariBariGood/manzanas";
            license = lib.licenses.asl20;
            sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
            mainProgram = "manzanasd";
            platforms = builtins.attrNames releaseHashes;
          };
        })
      ) { };
    in
    {
      packages.manzanas = manzanas;
    };
}
