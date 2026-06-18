{
  perSystem =
    { pkgs, ... }:
    let
      lean-ctx = pkgs.rustPlatform.buildRustPackage rec {
        pname = "lean-ctx";
        version = "3.8.8";

        src = pkgs.fetchFromGitHub {
          owner = "mattgmak";
          repo = "lean-ctx";
          rev = "ca9397ddc1ff6b15e1dbc0a31287b73579cf8102";
          hash = "sha256-aiErff8RhLE/3SVPYFhZIIioMmwpl6vdDQdu+tzIg1Y=";
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
