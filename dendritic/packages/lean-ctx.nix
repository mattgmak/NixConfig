{ inputs, ... }:
{
  perSystem =
    { pkgs, ... }:
    let
      lean-ctx = pkgs.rustPlatform.buildRustPackage rec {
        pname = "lean-ctx";
        version = "3.7.5";

        src = pkgs.fetchFromGitHub {
          owner = "yvgude";
          repo = "lean-ctx";
          rev = "v${version}";
          hash = "sha256-V/jjrVh0b/poIkDCDPvHREOAwEKOfEqJD8zfdCW42dQ=";
        };

        buildAndTestSubdir = "rust";

        prePatch = ''
          cp ${src}/rust/Cargo.lock Cargo.lock
        '';

        cargoLock.lockFile = "${src}/rust/Cargo.lock";

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
