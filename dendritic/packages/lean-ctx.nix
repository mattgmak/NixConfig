{ inputs, ... }:
{
  perSystem =
    { pkgs, ... }:
    let
      lean-ctx =
        pkgs.callPackage
          (
            {
              lib,
              stdenv,
              fetchurl,
              gnutar,
              makeWrapper,
              autoPatchelfHook,
              onnxruntime,
            }:
            let
              version = "3.10.2";
              baseUrl = "https://github.com/yvgude/lean-ctx/releases/download/v${version}";

              platformAttrs = {
                "aarch64-darwin" = {
                  asset = "lean-ctx-aarch64-apple-darwin.tar.gz";
                  hash = "sha256-odrDAadyNFIHKfFFGveVnWvcHbVoVhIwKDmMsG1nBhU=";
                };
                "x86_64-linux" = {
                  asset = "lean-ctx-x86_64-unknown-linux-gnu.tar.gz";
                  hash = "sha256-DHIyhOuInDWWgggIePxWUVrgP/d0K5jX5W+oo1u/8v4=";
                };
              };

              attrs =
                platformAttrs.${stdenv.hostPlatform.system}
                  or (throw "lean-ctx: unsupported platform ${stdenv.hostPlatform.system}; supported: aarch64-darwin, x86_64-linux");

              ortDylib =
                "${lib.getLib onnxruntime}/lib/libonnxruntime.${
                  if stdenv.hostPlatform.isDarwin then "dylib" else "so"
                }";

              runtimeDependencies = lib.optionals stdenv.hostPlatform.isLinux [
                stdenv.cc.cc.lib
              ];

              wrapperArgs = [
                "--set"
                "ORT_DYLIB_PATH"
                ortDylib
              ]
              ++ lib.optionals stdenv.hostPlatform.isLinux [
                "--prefix"
                "LD_LIBRARY_PATH"
                ":"
                (lib.makeLibraryPath runtimeDependencies)
              ];
            in
            stdenv.mkDerivation {
              pname = "lean-ctx";
              inherit version;

              src = fetchurl {
                url = "${baseUrl}/${attrs.asset}";
                hash = attrs.hash;
              };

              # Release archives contain one root-level executable.
              dontUnpack = true;

              nativeBuildInputs = [
                gnutar
                makeWrapper
              ]
              ++ lib.optionals stdenv.hostPlatform.isLinux [ autoPatchelfHook ];

              inherit runtimeDependencies;

              installPhase = ''
                runHook preInstall
                mkdir -p "$out/bin"
                ${lib.getExe gnutar} -xOf "$src" lean-ctx > "$out/bin/lean-ctx.real"
                chmod +x "$out/bin/lean-ctx.real"
                makeWrapper "$out/bin/lean-ctx.real" "$out/bin/lean-ctx" \
                  ${lib.escapeShellArgs wrapperArgs}
                runHook postInstall
              '';

              doCheck = false;
              doInstallCheck = stdenv.buildPlatform.canExecute stdenv.hostPlatform;

              installCheckPhase = ''
                runHook preInstallCheck
                "$out/bin/lean-ctx" --version | grep -F "lean-ctx ${version}"
                test -e "${ortDylib}"
                runHook postInstallCheck
              '';

              passthru = {
                inherit onnxruntime;
              };

              strictDeps = true;

              meta = with lib; {
                description = "Context Runtime for AI Agents — token compression, cross-session memory, CCP";
                homepage = "https://leanctx.com";
                license = licenses.asl20;
                sourceProvenance = with sourceTypes; [ binaryNativeCode ];
                platforms = builtins.attrNames platformAttrs;
                mainProgram = "lean-ctx";
              };
            }
          ) { };
    in
    {
      packages.lean-ctx = lean-ctx;
    };
}
