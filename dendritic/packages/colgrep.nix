{ inputs, ... }:
{
  perSystem =
    { pkgs, ... }:
    let
      colgrep = pkgs.callPackage (
        {
          lib,
          stdenv,
          fetchurl,
          autoPatchelfHook,
          makeWrapper,
          openssl,
        }:

        let
          version = "1.4.0";
          baseUrl = "https://github.com/lightonai/next-plaid/releases/download/v${version}";

          platformAttrs = {
            "x86_64-linux" = {
              target = "x86_64-unknown-linux-gnu";
              hash = "sha256-H9CDt48WRFtYi6UNAuEV5HR2Voy9pRABcO2xU5+JLAc=";
            };
            "aarch64-darwin" = {
              target = "aarch64-apple-darwin";
              hash = "sha256-s/7z+oUnN5Bdz+dPOHYWzNhwIY8qRgGj/l47M32DX+c=";
            };
            "x86_64-darwin" = {
              target = "x86_64-apple-darwin";
              hash = "sha256-ps0xzpJ9CJM6dCRnec1onj8So3CX1vr/jhuNLsvxC4A=";
            };
          };

          attrs =
            platformAttrs.${stdenv.hostPlatform.system}
              or (throw "colgrep: unsupported platform ${stdenv.hostPlatform.system}");
        in
        stdenv.mkDerivation {
          pname = "colgrep";
          inherit version;

          src = fetchurl {
            url = "${baseUrl}/colgrep-${attrs.target}.tar.xz";
            hash = attrs.hash;
          };

          nativeBuildInputs = lib.optionals stdenv.isLinux [
            autoPatchelfHook
            makeWrapper
          ];
          buildInputs = lib.optionals stdenv.isLinux [
            openssl
            stdenv.cc.cc.lib
          ];

          installPhase = ''
            runHook preInstall
            install -Dm755 colgrep $out/bin/colgrep-unwrapped
            if [ "$(uname -s)" = Linux ]; then
              makeWrapper $out/bin/colgrep-unwrapped $out/bin/colgrep \
                --prefix LD_LIBRARY_PATH : "${
                  lib.makeLibraryPath [
                    stdenv.cc.cc.lib
                    openssl
                  ]
                }"
            else
              mv $out/bin/colgrep-unwrapped $out/bin/colgrep
            fi
            runHook postInstall
          '';

          doCheck = false;
          doInstallCheck = true;
          installCheckPhase = ''
            $out/bin/colgrep --version | grep -F "${version}"
          '';

          meta = with lib; {
            description = "Semantic code search powered by ColBERT multi-vector embeddings";
            homepage = "https://github.com/lightonai/next-plaid";
            license = licenses.asl20;
            sourceProvenance = with sourceTypes; [ binaryNativeCode ];
            platforms = builtins.attrNames platformAttrs;
            mainProgram = "colgrep";
          };
        }
      ) { };
    in
    {
      packages.colgrep = colgrep;
    };
}
