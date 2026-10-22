{ inputs, ... }:
{
  perSystem =
    { pkgs, ... }:
    let
      launchk = pkgs.callPackage (
        {
          lib,
          stdenv,
          fetchurl,
          gnutar,
        }:

        let
          version = "0.3.1";
          baseUrl = "https://github.com/intellekthq/launchk/releases/download/launchk-${version}";
        in
        stdenv.mkDerivation {
          pname = "launchk";
          inherit version;

          # Upstream ships aarch64 only. Homebrew would build nothing here either,
          # and the binary keeps its upstream signature.
          src = fetchurl {
            url = "${baseUrl}/launchk-aarch64-apple-darwin.tar.gz";
            hash = "sha256-N1IpjOsFgWCkE70EHnZXUAMAGflRPywrlSDMsI2k+T8=";
          };

          dontUnpack = true;

          nativeBuildInputs = [ gnutar ];

          installPhase = ''
            runHook preInstall
            mkdir -p $out/bin
            ${lib.getExe gnutar} -xOf $src launchk > $out/bin/launchk
            chmod +x $out/bin/launchk
            runHook postInstall
          '';

          doCheck = false;

          meta = with lib; {
            description = "TUI to manage launchd jobs on macOS";
            homepage = "https://github.com/intellekthq/launchk";
            license = licenses.mit;
            sourceProvenance = with sourceTypes; [ binaryNativeCode ];
            platforms = [ "aarch64-darwin" ];
            mainProgram = "launchk";
          };
        }
      ) { };
    in
    {
      packages.launchk = launchk;
    };
}
