{
  inputs,
  self,
  ...
}:
{
  perSystem =
    { pkgs, ... }:
    let
      axe = pkgs.callPackage (
        {
          lib,
          stdenvNoCC,
          fetchurl,
        }:
        stdenvNoCC.mkDerivation (finalAttrs: {
          pname = "axe";
          version = "1.8.0";

          # Prebuilt Swift release. The upstream tarball is unpacked flat and no
          # build step exists here, so the whole tree stays together.
          src = fetchurl {
            url = "https://github.com/cameroncooke/AXe/releases/download/v${finalAttrs.version}/AXe-macOS-v${finalAttrs.version}-universal.tar.gz";
            hash = "sha256-e3Y0C3LpDQ8hG8fEY28VAJB27/B6zvLytjKxdd69iDQ=";
          };

          dontConfigure = true;
          dontBuild = true;
          # Signed Mach-O and frameworks, not build output.
          dontFixup = true;

          unpackPhase = ''
            mkdir -p source
            tar -xzf "$src" -C source
          '';
          sourceRoot = "source";

          # The binary links @executable_path/Frameworks. Keep axe beside its
          # Frameworks and bundle, and reach it through a wrapper.
          installPhase = ''
            runHook preInstall
            install -d "$out/libexec/axe" "$out/bin"
            cp -R . "$out/libexec/axe/"
            chmod +x "$out/libexec/axe/axe"
            makeWrapper "$out/libexec/axe/axe" "$out/bin/axe" \
              --prefix DYLD_FRAMEWORK_PATH : "$out/libexec/axe/Frameworks"
            runHook postInstall
          '';

          nativeBuildInputs = [ pkgs.makeWrapper ];

          meta = {
            description = "iOS Simulator automation CLI (AXe)";
            homepage = "https://github.com/cameroncooke/AXe";
            license = lib.licenses.mit;
            sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
            mainProgram = "axe";
            platforms = [ "aarch64-darwin" ];
          };
        })
      ) { };
    in
    {
      packages.axe = axe;
    };
}
