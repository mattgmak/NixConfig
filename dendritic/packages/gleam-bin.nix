{ inputs, ... }:
{
  perSystem =
    { system, ... }:
    let
      # Unoverlaid nixpkgs: the gleam overlay points at this derivation, so building
      # it from the overlaid pkgs would recurse back into the overlay.
      pkgs = import inputs.nixpkgs { inherit system; };
      gleamBin = pkgs.callPackage (
        {
          lib,
          stdenv,
          fetchurl,
        }:

        # TODO: drop this package once the pinned nixpkgs gleam is not a source build.
        # nixpkgs builds gleam with rustPlatform.buildRustPackage, which needs the
        # whole Rust toolchain on every bump.
        let
          version = "1.19.2";
          srcs = {
            aarch64-darwin = {
              url = "https://github.com/gleam-lang/gleam/releases/download/v${version}/gleam-v${version}-aarch64-apple-darwin.tar.gz";
              hash = "sha256-+nxhE+Fiqx2Xn3Ln3ePpB7h+SzDFGK8Xh2jld9GAMk0=";
            };
            x86_64-linux = {
              url = "https://github.com/gleam-lang/gleam/releases/download/v${version}/gleam-v${version}-x86_64-unknown-linux-musl.tar.gz";
              hash = "sha256-K6Kvtmyp9tzAGkpukWm2lCljutZIO+yVcd3AeM/m9B8=";
            };
          };
          src =
            srcs.${stdenv.hostPlatform.system}
              or (throw "gleam ${version}: no upstream archive for ${stdenv.hostPlatform.system}");

          # The archives ship only the bare binary. Upstream spells the file LICENCE.
          licence = fetchurl {
            url = "https://raw.githubusercontent.com/gleam-lang/gleam/v${version}/LICENCE";
            hash = "sha256-xx0jnfkXJvxRnG63LTGOxlggYnIysveWIZ6H3PNdCrQ=";
          };
        in
        stdenv.mkDerivation {
          pname = "gleam";
          inherit version;

          src = fetchurl {
            inherit (src) url hash;
          };

          # Both archives hold a single `gleam` file at the root, so no sourceRoot shift.
          # The linux build is static-pie, so no autoPatchelfHook and no extra libraries.
          sourceRoot = ".";

          installPhase = ''
            runHook preInstall
            install -Dm755 gleam $out/bin/gleam
            install -Dm644 ${licence} $out/share/licenses/gleam/LICENCE
            runHook postInstall
          '';

          meta = {
            description = "Statically typed language for the Erlang VM, prebuilt upstream binary";
            homepage = "https://gleam.run/";
            license = lib.licenses.asl20;
            mainProgram = "gleam";
            sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
            platforms = builtins.attrNames srcs;
          };
        }
      ) { };
    in
    {
      packages.gleamBin = gleamBin;
    };
}
