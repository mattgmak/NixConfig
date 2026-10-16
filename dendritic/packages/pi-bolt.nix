{
  perSystem =
    { pkgs, ... }:
    let
      piPkg = pkgs.callPackage (
        {
          lib,
          stdenv,
          fetchurl,
          gnutar,
          xz,
          makeWrapper,
        }:
        let
          version = "0.9.1";

          # Asset names are stable across releases (scripts/package-release.sh).
          # linux-x64 = AVX2 build; -baseline (SSE4.2) and -jit variants exist too.
          platformAttrs = {
            "aarch64-darwin" = {
              variant = "darwin-arm64";
              hash = "sha256-Hzfjtq49KSbZRGnTKYv7gYGJqIT4pLWlGphkSDoFdzY=";
            };
            "x86_64-linux" = {
              variant = "linux-x64";
              hash = "sha256-SQQwqEp4RO1JwQKAJzf2e489fxOHDUWAOkhUS0owKI8=";
            };
          };

          attrs =
            platformAttrs.${stdenv.hostPlatform.system}
              or (throw "pi-bolt: unsupported platform ${stdenv.hostPlatform.system}");

          asset = "pi-bolt-${attrs.variant}";
        in
        stdenv.mkDerivation {
          pname = "pi";
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

            # The whole directory must stay together: the runtime reads package.json,
            # theme/ and export-html/ next to the executable.
            mkdir -p $out/libexec
            cp -R . $out/libexec/pi

            # The darwin build splits the app: a 36K `pi` launcher execs the real `pi-bin`
            # beside it, so the running app is named `pi-bin` (tmux pane_current_command,
            # Activity Monitor, any exec-path reader). Swap them: real app becomes `pi`,
            # launcher stays usable as `pi-launcher`, `pi-bin` becomes a symlink so the
            # launcher's `%s/pi-bin` lookup keeps resolving. linux-x64 ships one
            # self-contained `pi`, so the swap is darwin-only.
            if [ -e $out/libexec/pi/pi-bin ]; then
              mv $out/libexec/pi/pi $out/libexec/pi/pi-launcher
              mv $out/libexec/pi/pi-bin $out/libexec/pi/pi
              ln -s pi $out/libexec/pi/pi-bin
            fi

            # Never copy `pi` alone into bin/. PIBOLT_NPM marks it as package-managed so
            # `pi-bolt update` refuses to curl-install into ~/.pi-bolt.
            # PI_PACKAGE_DIR must be pinned to our own layout: it is inherited from any
            # parent pi process (and wins over the binary's own dirname), and a foreign
            # value silently redirects asset lookup (`--export` ENOENT, wrong --version).
            # Exec the app directly instead of the launcher: one less exec hop, and the
            # launcher's own name would leak back into exec-path process listings.
            # --argv0 pi: macOS comm is argv[0] truncated to 16 bytes, so the default
            # full store path would become the process name.
            makeWrapper $out/libexec/pi/pi $out/bin/pi \
              --argv0 pi \
              --set PIBOLT_NPM 1 \
              --set PI_TELEMETRY 0 \
              --set PI_PACKAGE_DIR $out/libexec/pi

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
      packages.pi = piPkg;
    };
}
