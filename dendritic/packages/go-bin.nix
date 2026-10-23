{ inputs, ... }:
{
  perSystem =
    { system, ... }:
    let
      # Unoverlaid nixpkgs: the go overlay points at this derivation, so building
      # it from the overlaid pkgs would recurse back into the overlay.
      pkgs = import inputs.nixpkgs { inherit system; };
      goBin = pkgs.callPackage (
        {
          lib,
          stdenv,
          fetchurl,
        }:

        # TODO: drop this package once nixpkgs go_1_27 reaches 1.27.3 in the binary cache.
        # 1.27.3 is the release that denylists the compromised eMudhra intermediates.
        let
          version = "1.27.3";
          srcs = {
            aarch64-darwin = {
              url = "https://go.dev/dl/go${version}.darwin-arm64.tar.gz";
              hash = "sha256-3TkIzyCVnXmMHgbr5bciE/BQXOATc7QM4xEJdabNmcI=";
              dir = "go";
            };
            x86_64-linux = {
              url = "https://go.dev/dl/go${version}.linux-amd64.tar.gz";
              hash = "sha256-Ze+8gP3B+izSYxytW0gXd6aOhyXzTon1D8ascU43m0A=";
              dir = "go";
            };
          };
          src =
            srcs.${stdenv.hostPlatform.system}
              or (throw "go ${version}: no upstream archive for ${stdenv.hostPlatform.system}");
        in
        stdenv.mkDerivation {
          pname = "go";
          inherit version;

          src = fetchurl {
            inherit (src) url hash;
          };

          sourceRoot = src.dir;

          # The whole tree stays in one output, so bin/go walks up to find GOROOT.
          dontPatchELF = true;
          dontStrip = true;

          installPhase = ''
            runHook preInstall
            install -d $out
            cp -a ./. $out/
            runHook postInstall
          '';

          meta = {
            description = "Go programming language, prebuilt upstream binary";
            homepage = "https://go.dev";
            license = lib.licenses.bsd3;
            mainProgram = "go";
            sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
            platforms = builtins.attrNames srcs;
          };
        }
      ) { };
    in
    {
      packages.goBin = goBin;
    };
}
