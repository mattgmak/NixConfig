{ inputs, ... }:
{
  perSystem =
    { pkgs, ... }:
    let
      engram = pkgs.callPackage (
        {
          lib,
          stdenv,
          fetchurl,
          gnutar,
        }:

        let
          version = "1.16.1";
          baseUrl = "https://github.com/Gentleman-Programming/engram/releases/download/v${version}";

          platformAttrs = {
            "x86_64-linux" = {
              asset = "linux_amd64";
              hash = "sha256-2VIC8ZJ9FCz+DXZPTEvHqiFx6FuZ+upq7fzJArc9vfc=";
            };
            "aarch64-linux" = {
              asset = "linux_arm64";
              hash = "sha256-VqLLPLfgPcf8J+770eKqXvmg2Znha5IOOSv6MQPSeCc=";
            };
            "aarch64-darwin" = {
              asset = "darwin_arm64";
              hash = "sha256-sMu2xUVGnqYwb5UpLk6KAssaj0/LDcWsmb6TqMW/xsI=";
            };
            "x86_64-darwin" = {
              asset = "darwin_amd64";
              hash = "sha256-CjJ1A0teQUDjq9XFN4qKer73sLAAfAtcRZnAnz0ZicI=";
            };
          };

          attrs =
            platformAttrs.${stdenv.hostPlatform.system}
              or (throw "engram: unsupported platform ${stdenv.hostPlatform.system}");
        in
        stdenv.mkDerivation {
          pname = "engram";
          inherit version;

          src = fetchurl {
            url = "${baseUrl}/engram_${version}_${attrs.asset}.tar.gz";
            hash = attrs.hash;
          };

          # Release archives are flat (binary + docs at archive root).
          dontUnpack = true;

          nativeBuildInputs = [ gnutar ];

          installPhase = ''
            runHook preInstall
            mkdir -p $out/bin
            ${lib.getExe gnutar} -xOf $src engram > $out/bin/engram
            chmod +x $out/bin/engram
            runHook postInstall
          '';

          doCheck = false;
          doInstallCheck = true;
          installCheckPhase = ''
            $out/bin/engram version | grep -F "${version}"
          '';

          meta = with lib; {
            description = "Persistent memory for AI coding agents";
            homepage = "https://github.com/Gentleman-Programming/engram";
            license = licenses.mit;
            sourceProvenance = with sourceTypes; [ binaryNativeCode ];
            platforms = builtins.attrNames platformAttrs;
            mainProgram = "engram";
          };
        }
      ) { };
    in
    {
      packages.engram = engram;
    };
}
