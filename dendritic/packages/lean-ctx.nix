{
  perSystem =
    { pkgs, ... }:
    let
      lean-ctx = pkgs.rustPlatform.buildRustPackage rec {
        pname = "lean-ctx";
        version = "3.9.9";

        src = pkgs.lib.cleanSource ../home-modules/pi-coding-agent/extensions/vendor/lean-ctx;

        buildAndTestSubdir = "rust";

        prePatch = ''
          cp ${src}/rust/Cargo.lock Cargo.lock
        '';

        cargoLock = {
          lockFile = "${src}/rust/Cargo.lock";
          outputHashes = {
            "rmcp-2.0.0" = "sha256-BHuCm7JOKWKa4mkHPrzJ7hGLWL3F4+nB7X1bJ2kEgXQ=";
          };
        };


        nativeBuildInputs = with pkgs; [
          cmake
          pkg-config
        ];

        buildInputs = with pkgs; [
          openssl
        ];

        doCheck = false;

        meta = with pkgs.lib; {
          description = "Context Runtime for AI Agents — token compression, cross-session memory, CCP";
          homepage = "https://leanctx.com";
          license = licenses.asl20;
          platforms = platforms.all;
          mainProgram = "lean-ctx";
        };
      };
    in
    {
      packages.lean-ctx = lean-ctx;
    };
}
