{ inputs, ... }:
{
  perSystem =
    { system, ... }:
    let
      # Unoverlaid nixpkgs: the yazi overlay points at this derivation, so
      # building it from the overlaid pkgs would recurse back into the overlay.
      pkgs = import inputs.nixpkgs { inherit system; };
      yaziBin = pkgs.callPackage (
        {
          lib,
          stdenv,
          fetchurl,
          unzip,
          autoPatchelfHook,
        }:

        # TODO: drop this package once nixpkgs ships yazi 26.9.1 in the binary cache.
        let
          version = "26.9.1";
          srcs = {
            aarch64-darwin = {
              url = "https://github.com/sxyazi/yazi/releases/download/v${version}/yazi-aarch64-apple-darwin.zip";
              hash = "sha256-OSEYKiHM6wpQXl2sV44Uh9SBBMql8RTp+K30C1pyiak=";
              dir = "yazi-aarch64-apple-darwin";
            };
            x86_64-linux = {
              url = "https://github.com/sxyazi/yazi/releases/download/v${version}/yazi-x86_64-unknown-linux-gnu.zip";
              hash = "sha256-oC/pHTMEKUBIxoHwEPEQCFaHKk6Y7PaScyjoiNQKatI=";
              dir = "yazi-x86_64-unknown-linux-gnu";
            };
            aarch64-linux = {
              url = "https://github.com/sxyazi/yazi/releases/download/v${version}/yazi-aarch64-unknown-linux-gnu.zip";
              hash = "sha256-AoB/CNa1ibZbdRak4lnYP1mV16I7sSs6FVFBOFs3Czo=";
              dir = "yazi-aarch64-unknown-linux-gnu";
            };
          };
          src =
            srcs.${stdenv.hostPlatform.system}
              or (throw "yazi ${version}: no upstream archive for ${stdenv.hostPlatform.system}");
        in
        stdenv.mkDerivation {
          pname = "yazi";
          inherit version;

          src = fetchurl {
            inherit (src) url hash;
          };

          # The linux builds want libgcc_s. The darwin build is a plain Mach-O.
          nativeBuildInputs = [ unzip ] ++ lib.optionals stdenv.hostPlatform.isLinux [ autoPatchelfHook ];
          buildInputs = lib.optionals stdenv.hostPlatform.isLinux [ stdenv.cc.cc.lib ];

          sourceRoot = src.dir;

          # No upstream archive ships a desktop entry, so none is installed.
          installPhase = ''
            runHook preInstall
            install -Dm755 yazi $out/bin/yazi
            install -Dm755 ya $out/bin/ya
            install -Dm644 LICENSE $out/share/licenses/yazi/LICENSE
            if [ -d completions ]; then
              install -Dm644 completions/yazi.bash $out/share/bash-completion/completions/yazi
              install -Dm644 completions/yazi.fish $out/share/fish/vendor_completions.d/yazi.fish
              install -Dm644 completions/_yazi $out/share/zsh/site-functions/_yazi
            fi
            runHook postInstall
          '';

          meta = {
            description = "Blazing fast terminal file manager, prebuilt upstream binary";
            homepage = "https://github.com/sxyazi/yazi";
            license = lib.licenses.mit;
            mainProgram = "yazi";
            sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
            platforms = builtins.attrNames srcs;
          };
        }
      ) { };
    in
    {
      packages.yaziBin = yaziBin;
    };
}
