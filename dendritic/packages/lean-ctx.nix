{
  perSystem =
    { pkgs, ... }:
    let
      lean-ctx = pkgs.rustPlatform.buildRustPackage rec {
        pname = "lean-ctx";
        version = "3.9.3";

        src = pkgs.fetchFromGitHub {
          owner = "mattgmak";
          repo = "lean-ctx";
          rev = "79b7df01c7dbaacd461e32f33b2a3c46b3c5357e";
          hash = "sha256-Fbo3znpZPEbrBlJdvAWvAFPMPv6dlmVc/IIC1/y10EU=";
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
