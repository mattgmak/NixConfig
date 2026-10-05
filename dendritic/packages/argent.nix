{ inputs, ... }:
{
  perSystem =
    { pkgs, ... }:
    let
      argent =
        pkgs.callPackage
          (
            {
              lib,
              stdenv,
              stdenvNoCC,
              fetchurl,
              makeWrapper,
              nodejs_22,
              patchelf,
              libgcc,
            }:
            let
              version = "0.27.0";
              npmTarball = fetchurl {
                url = "https://registry.npmjs.org/@swmansion/argent/-/argent-${version}.tgz";
                hash = "sha256-6qLoy9hO6HF2GHoQyRP+4cCLpKElMfiaWQ+nbFNnOls=";
              };

              # hostPlatformKey() from the bundled tool-server / bin/argent-simulator-server.cjs.
              platformKey =
                if stdenv.hostPlatform.isLinux then "linux" else "darwin";

              # The tool-server spawns bin/<platformKey>/simulator-server itself (execFileSync, no
              # wrapper in between), so the Linux ELF has to be self-contained: /lib64/ld-linux does
              # not exist on NixOS, libgcc_s.so.1 lives in the gcc lib dir, and the Rust binary
              # lists ld-linux-x86-64.so.2 as a DT_NEEDED so glibc's lib dir must be on RUNPATH
              # too (runpath, not --force-rpath, so it does not leak into the server's children).
              simulatorServerPatch = lib.optionalString stdenv.hostPlatform.isLinux ''
                patchelf \
                  --set-interpreter ${stdenv.cc.bintools.dynamicLinker} \
                  --set-rpath ${lib.makeLibraryPath [ stdenv.cc.cc.lib libgcc ]} \
                  "$out/libexec/argent/bin/linux/simulator-server"
              '';

              # ax-service is a Mach-O slice in every variant, including the "platform-neutral"
              # bin/tcp one, so it stays darwin-only.
              axServiceLink = lib.optionalString stdenv.hostPlatform.isDarwin ''
                ln -s "$out/libexec/argent/bin/darwin/ax-service" "$out/bin/ax-service"
              '';
            in
            stdenvNoCC.mkDerivation {
              pname = "argent";
              inherit version;
              src = npmTarball;

              nativeBuildInputs =
                [
                  nodejs_22
                  makeWrapper
                ]
                ++ lib.optionals stdenv.hostPlatform.isLinux [ patchelf ];

              dontConfigure = true;
              dontBuild = true;

              # Prebuilt Mach-O/ELF blobs shipped by the npm release, not build output:
              # leave the binaries alone (no autoPatchelf).
              dontPatchELF = true;

              unpackPhase = ''
                tar -xzf "$src"
              '';

              sourceRoot = "package";

              installPhase = ''
                runHook preInstall

                mkdir -p "$out/libexec/argent"
                cp -r . "$out/libexec/argent/"
                chmod +x "$out/libexec/argent/bin"/* "$out/libexec/argent/bin"/*/* 2>/dev/null || true

                mkdir -p "$out/bin"

                # dist/ ships esbuild bundles, so no node_modules install is needed.
                makeWrapper ${nodejs_22}/bin/node "$out/bin/argent" \
                  --add-flags "$out/libexec/argent/dist/cli.js"

                ln -s "$out/libexec/argent/bin/${platformKey}/simulator-server" \
                  "$out/bin/argent-simulator-server"

                ${simulatorServerPatch}

                ${axServiceLink}

                runHook postInstall
              '';

              doCheck = false;

              passthru = {
                inherit version;
              };

              strictDeps = true;

              meta = {
                description = "Agentic toolkit for iOS Simulator and Android Emulator (MCP)";
                homepage = "https://github.com/software-mansion/argent";
                license = lib.licenses.asl20;
                mainProgram = "argent";
                platforms = lib.platforms.unix;
              };
            }
          )
          { };
    in
    {
      packages.argent = argent;
    };
}