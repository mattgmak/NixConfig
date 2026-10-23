{ inputs, ... }:
{
  perSystem =
    { system, ... }:
    let
      pkgs = import inputs.nixpkgs { inherit system; };
      bunBin = pkgs.callPackage (
        {
          lib,
          stdenvNoCC,
          fetchurl,
          unzip,
          autoPatchelfHook,
          openssl,
          cctools,
          darwin,
          rcodesign,
        }:

        let
          # TODO: drop this package once nixpkgs ships bun 1.4.4.
          version = "1.4.4";
          srcs = {
            aarch64-darwin = {
              url = "https://github.com/oven-sh/bun/releases/download/bun-v${version}/bun-darwin-aarch64.zip";
              hash = "sha256-wkDX8My5DCY6hJ/NsJt+5iYw2SE0jtaq/ahrnVd7xRA=";
              dir = "bun-darwin-aarch64";
            };
            x86_64-linux = {
              # Baseline build: the non-baseline one needs AVX2.
              url = "https://github.com/oven-sh/bun/releases/download/bun-v${version}/bun-linux-x64-baseline.zip";
              hash = "sha256-4ERutVmVdy65iUvrrppr42jZhai5Jx7hJEhvmUbu3XY=";
              dir = "bun-linux-x64-baseline";
            };
          };
          src =
            srcs.${stdenvNoCC.hostPlatform.system}
              or (throw "bun ${version}: no upstream archive for ${stdenvNoCC.hostPlatform.system}");

          # The archives ship no license files.
          license = fetchurl {
            url = "https://raw.githubusercontent.com/oven-sh/bun/bun-v${version}/LICENSE.md";
            hash = "sha256-Ni/jLJVOyCkkC9dCnFPXBe7wjGv6Rf/C0CAF+FfLpN0=";
          };
        in
        stdenvNoCC.mkDerivation {
          pname = "bun";
          inherit version;

          src = fetchurl {
            inherit (src) url hash;
          };

          nativeBuildInputs = [ unzip ] ++ lib.optionals stdenvNoCC.hostPlatform.isLinux [ autoPatchelfHook ];
          buildInputs = lib.optionals stdenvNoCC.hostPlatform.isLinux [ openssl ];

          sourceRoot = src.dir;

          dontConfigure = true;
          dontBuild = true;

          installPhase = ''
            runHook preInstall
            install -Dm755 bun $out/bin/bun
            ln -s $out/bin/bun $out/bin/bunx
            install -Dm644 ${license} $out/share/licenses/bun/LICENSE.md
            runHook postInstall
          '';

          # The darwin binary links /usr/lib/libicucore.A.dylib and is linker-signed.
          postPhases = [ "postPatchelf" ];
          postPatchelf = lib.optionalString stdenvNoCC.hostPlatform.isDarwin ''
            '${lib.getExe' cctools "${cctools.targetPrefix}install_name_tool"}' $out/bin/bun \
              -change /usr/lib/libicucore.A.dylib '${lib.getLib darwin.ICU}/lib/libicucore.A.dylib'
            '${lib.getExe rcodesign}' sign --code-signature-flags linker-signed $out/bin/bun
          '';

          meta = {
            description = "Fast JavaScript runtime, bundler, test runner and package manager, prebuilt upstream binary";
            homepage = "https://github.com/oven-sh/bun";
            license = with lib.licenses; [
              mit
              lgpl21Only
            ];
            mainProgram = "bun";
            sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
            platforms = builtins.attrNames srcs;
          };
        }
      ) { };
    in
    {
      packages.bunBin = bunBin;
    };
}
