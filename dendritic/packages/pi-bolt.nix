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
          version = "0.7.2";

          # Asset names are stable across releases (scripts/package-release.sh).
          # linux-x64 = AVX2 build; -baseline (SSE4.2) and -jit variants exist too.
          platformAttrs = {
            "aarch64-darwin" = {
              variant = "darwin-arm64";
              hash = "sha256-l1CvMpEFKGDOrF84+Y3LI3oAjqNBU0rVzhQcqADOSAY=";
            };
            "x86_64-linux" = {
              variant = "linux-x64";
              hash = "sha256-9ZwQBt9JWR9iUFznj8Jq3jMQEByKBxTbZYw+7PBOy5I=";
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

            # The whole directory must stay together: `pi-launcher` is a thin launcher that
            # execs the `pi` beside its own realpath, and the runtime reads package.json,
            # theme/ and export-html/ next to the executable.
            mkdir -p $out/libexec
            cp -R . $out/libexec/pi

            # The 36K `pi` is a thin launcher that execs the real app beside itself as
            # `%s/pi-bin`. tmux names panes/windows after the resolved executable basename,
            # not argv0, so swap the names: real app -> `pi`, launcher -> `pi-launcher`, with a
            # `pi-bin` symlink so the launcher still finds it.
            mv $out/libexec/pi/pi $out/libexec/pi/pi-launcher
            mv $out/libexec/pi/pi-bin $out/libexec/pi/pi
            ln -s pi $out/libexec/pi/pi-bin

            # Never copy `pi` alone into bin/. PIBOLT_NPM marks it as package-managed so
            # `pi-bolt update` refuses to curl-install into ~/.pi-bolt.
            # PI_PACKAGE_DIR must be pinned to our own layout: it is inherited from any
            # parent pi process (and wins over the binary's own dirname), and a foreign
            # value silently redirects asset lookup (`--export` ENOENT, wrong --version).
            # --argv0 pi: macOS ps comm is argv[0], so the default full store path would
            # become the process name.
            makeWrapper $out/libexec/pi/pi-launcher $out/bin/pi \
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
