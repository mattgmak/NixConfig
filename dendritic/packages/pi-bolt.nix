{
  perSystem =
    { pkgs, ... }:
    let
      piBolt = pkgs.callPackage (
        {
          lib,
          stdenv,
          fetchurl,
          gnutar,
          xz,
          makeWrapper,
        }:
        let
          version = "0.7.1";

          # Asset names are stable across releases (scripts/package-release.sh).
          # linux-x64 = AVX2 build; -baseline (SSE4.2) and -jit variants exist too.
          platformAttrs = {
            "aarch64-darwin" = {
              variant = "darwin-arm64";
              hash = "sha256-0ehHGQ8XDjX6hME2fkH7k9ehTQxmrct/Zlf3knmms2g=";
            };
            "x86_64-linux" = {
              variant = "linux-x64";
              hash = "sha256-5uKL91rt9LQRqOMh+t9wD5Q1+TcVTXxOXqDc4HaX18k=";
            };
          };

          attrs =
            platformAttrs.${stdenv.hostPlatform.system}
              or (throw "pi-bolt: unsupported platform ${stdenv.hostPlatform.system}");

          asset = "pi-bolt-${attrs.variant}";
        in
        stdenv.mkDerivation {
          pname = "pi-bolt";
          inherit version;

          src = fetchurl {
            url = "https://github.com/opensec-git/Pi-Bolt/releases/download/bolt-v${version}/${asset}.tar.xz";
            hash = attrs.hash;
          };

          nativeBuildInputs = [
            gnutar
            xz
            makeWrapper
          ];

          # AOT image: page-aligned sections appended to the executable with offsets in a
          # trailer, and the runtime re-opens its own file to verify it. Strip/patchelf/sign
          # rewrites corrupt or break it, so no fixup at all.
          dontFixup = true;
          dontStrip = true;

          unpackPhase = ''
            runHook preUnpack
            mkdir -p source
            ${lib.getExe' xz "xz"} -dc $src | ${lib.getExe gnutar} -xf - -C source
            cd source/${asset}
            runHook postUnpack
          '';

          installPhase = ''
            runHook preInstall

            # The whole directory must stay together: `pi` is a launcher that spawns the
            # `pi-bin` beside its own realpath, and the runtime reads package.json,
            # theme/ and export-html/ next to the executable.
            mkdir -p $out/libexec
            cp -R . $out/libexec/pi-bolt

            # Never copy `pi` alone into bin/. PIBOLT_NPM marks it as package-managed so
            # `pi-bolt update` refuses to curl-install into ~/.pi-bolt.
            # PI_PACKAGE_DIR must be pinned to our own layout: it is inherited from any
            # parent pi process (and wins over the binary's own dirname), and a foreign
            # value silently redirects asset lookup (`--export` ENOENT, wrong --version).
            # `pi` is the in-place swap name (installed via the pi-coding-agent overlay),
            # `pi-bolt` keeps the package usable side by side.
            for bin in pi pi-bolt; do
              makeWrapper $out/libexec/pi-bolt/pi $out/bin/$bin \
                --set PIBOLT_NPM 1 \
                --set PI_TELEMETRY 0 \
                --set PI_PACKAGE_DIR $out/libexec/pi-bolt
            done

            runHook postInstall
          '';

          meta = with lib; {
            description = "Pi coding agent compiled ahead of time to native code (fork of earendil-works/pi)";
            homepage = "https://github.com/opensec-git/Pi-Bolt";
            license = licenses.mit;
            sourceProvenance = with sourceTypes; [ binaryNativeCode ];
            platforms = builtins.attrNames platformAttrs;
            mainProgram = "pi";
          };
        }
      ) { };
    in
    {
      packages.pi-bolt = piBolt;
    };
}
