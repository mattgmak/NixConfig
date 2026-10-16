{ inputs, ... }:
{
  perSystem =
    { pkgs, ... }:
    let
      lean-ctx = pkgs.callPackage (
        {
          lib,
          stdenv,
          rustPlatform,
          fetchFromGitHub,
          makeWrapper,
          cmake,
          pkg-config,
          onnxruntime,
        }:
        let
          # Upstream has no release containing the shell-hook / jemalloc
          # fixes merged 2026-10-15; build the fork tip from source instead
          # of pinning a stale release asset. Drop this and go back to
          # fetchurl once upstream tags a release past b4dea0cc2.
          version = "3.11.4-unstable-2026-10-16";
          rev = "b4dea0cc2022c1484148cc2473b5e03169534dbb";

          ortDylib = "${lib.getLib onnxruntime}/lib/libonnxruntime.${
            if stdenv.hostPlatform.isDarwin then "dylib" else "so"
          }";
        in
        rustPlatform.buildRustPackage {
          pname = "lean-ctx";
          inherit version;

          src = fetchFromGitHub {
            owner = "mattgmak";
            repo = "lean-ctx";
            inherit rev;
            hash = "sha256-X42gqOwx1Y08z2rk4EmCN9p3tiEzbJIKTjKhq7O8kLY=";
          };

          cargoRoot = "rust";
          buildAndTestSubdir = "rust";
          cargoHash = "sha256-an4/7JYKOfhIebk6tK8ymmcr09FFIvCTwayRjw3ET0s=";

          # aws-lc-sys (rustls default provider) builds with cmake;
          # pkg-config resolves the system openssl/zstd probes.
          nativeBuildInputs = [
            cmake
            pkg-config
            makeWrapper
          ];

          # `ort` is built with `load-dynamic`; the engine dlopens
          # libonnxruntime at runtime, so point the wrapper at nixpkgs'.
          postFixup = ''
            wrapProgram "$out/bin/lean-ctx" --set ORT_DYLIB_PATH "${ortDylib}"
          '';

          doCheck = false;
          doInstallCheck = stdenv.buildPlatform.canExecute stdenv.hostPlatform;

          installCheckPhase = ''
            runHook preInstallCheck
            "$out/bin/lean-ctx" --version | grep -F "lean-ctx 3.11.4"
            test -e "${ortDylib}"
            runHook postInstallCheck
          '';

          passthru = {
            inherit onnxruntime;
          };

          strictDeps = true;

          meta = with lib; {
            description = "Context Runtime for AI Agents — token compression, cross-session memory, CCP";
            homepage = "https://leanctx.com";
            license = licenses.asl20;
            platforms = [
              "aarch64-darwin"
              "x86_64-linux"
            ];
            mainProgram = "lean-ctx";
          };
        }
      ) { };
    in
    {
      packages.lean-ctx = lean-ctx;
    };
}
