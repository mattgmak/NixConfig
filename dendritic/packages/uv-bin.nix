{ inputs, ... }:
{
  perSystem =
    { system, ... }:
    let
      # Unoverlaid nixpkgs: the uv overlay points at this derivation, so building
      # it from the overlaid pkgs would recurse back into the overlay.
      pkgs = import inputs.nixpkgs { inherit system; };
      uvBin = pkgs.callPackage (
        {
          lib,
          stdenv,
          fetchurl,
          autoPatchelfHook,
        }:

        # TODO: drop this package once nixpkgs ships uv 0.13.4 in the binary cache.
        let
          version = "0.13.4";
          srcs = {
            aarch64-darwin = {
              url = "https://github.com/astral-sh/uv/releases/download/${version}/uv-aarch64-apple-darwin.tar.gz";
              hash = "sha256-4LHUdDzmTFXZ8PSkRK+muBElaABw7gToU/zQ9sHr+PE=";
              dir = "uv-aarch64-apple-darwin";
            };
            x86_64-linux = {
              url = "https://github.com/astral-sh/uv/releases/download/${version}/uv-x86_64-unknown-linux-gnu.tar.gz";
              hash = "sha256-K0KDlvElctRCnPIQyiNN1ZmjOzrwlYpNXtVp1j4/NE8=";
              dir = "uv-x86_64-unknown-linux-gnu";
            };
          };
          src =
            srcs.${stdenv.hostPlatform.system}
              or (throw "uv ${version}: no upstream archive for ${stdenv.hostPlatform.system}");

          # The archives ship no license files.
          mitLicense = fetchurl {
            url = "https://raw.githubusercontent.com/astral-sh/uv/${version}/LICENSE-MIT";
            hash = "sha256-hg49eoa4TmpwEsemNfxk30dc68bM403+tzpZguxYF2w=";
          };
          apacheLicense = fetchurl {
            url = "https://raw.githubusercontent.com/astral-sh/uv/${version}/LICENSE-APACHE";
            hash = "sha256-xx0jnfkXJvxRnG63LTGOxlggYnIysveWIZ6H3PNdCrQ=";
          };
        in
        stdenv.mkDerivation {
          pname = "uv";
          inherit version;

          src = fetchurl {
            inherit (src) url hash;
          };

          # The linux build is a PIE that wants libgcc_s.
          # The darwin build is a plain Mach-O and needs no patching.
          nativeBuildInputs = lib.optionals stdenv.hostPlatform.isLinux [ autoPatchelfHook ];
          buildInputs = lib.optionals stdenv.hostPlatform.isLinux [ stdenv.cc.cc.lib ];

          sourceRoot = src.dir;

          installPhase = ''
            runHook preInstall
            install -Dm755 uv $out/bin/uv
            install -Dm755 uvx $out/bin/uvx
            install -Dm644 ${mitLicense} $out/share/licenses/uv/LICENSE-MIT
            install -Dm644 ${apacheLicense} $out/share/licenses/uv/LICENSE-APACHE
            runHook postInstall
          '';

          meta = {
            description = "Fast Python package manager, prebuilt upstream binary";
            homepage = "https://github.com/astral-sh/uv";
            license = with lib.licenses; [
              mit
              asl20
            ];
            mainProgram = "uv";
            sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
            platforms = builtins.attrNames srcs;
          };
        }
      ) { };
    in
    {
      packages.uvBin = uvBin;
    };
}
