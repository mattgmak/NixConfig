{
  perSystem =
    { pkgs, ... }:
    let
      version = "4.8.2";

      # What: bladebro, an agentic browser driver for AI agents.
      # From: the npm platform packages bladebro-linux-x64, bladebro-linux-arm64,
      # bladebro-darwin-arm64. Each tarball ships package/bladebro, a prebuilt binary.
      # Why: replaces the vendored vercel-labs/agent-browser binary for pi and Hermes.
      # The mcp-adapter exposes it as `bladebro mcp`.
      platformAttrs = {
        "x86_64-linux" = {
          url = "https://registry.npmjs.org/bladebro-linux-x64/-/bladebro-linux-x64-4.8.2.tgz";
          hash = "sha256-oN/PV/t5hk0oWpzoT313sL1WK3urPNMenAkpv5sX17I=";
        };
        "aarch64-linux" = {
          url = "https://registry.npmjs.org/bladebro-linux-arm64/-/bladebro-linux-arm64-4.8.2.tgz";
          hash = "sha256-Pkegg2TATH2IroaEw4Mp+MjQvfhgP8RUpjc++pNwqKU=";
        };
        "aarch64-darwin" = {
          url = "https://registry.npmjs.org/bladebro-darwin-arm64/-/bladebro-darwin-arm64-4.8.2.tgz";
          hash = "sha256-88tZqwmGP3KP6kbVXRWc7feJ5DXP4wc3jTu3uHouWng=";
        };
      };

      attrs =
        platformAttrs.${pkgs.stdenv.hostPlatform.system}
          or (throw "bladebro: unsupported platform ${pkgs.stdenv.hostPlatform.system}");
    in
    {
      packages.bladebro = pkgs.stdenv.mkDerivation {
        pname = "bladebro";
        inherit version;

        src = pkgs.fetchurl {
          url = attrs.url;
          hash = attrs.hash;
        };

        nativeBuildInputs = [
          pkgs.gnutar
          pkgs.gzip
        ];

        # Prebuilt binary: no build, no patchelf, no strip.
        dontBuild = true;
        dontFixup = true;

        unpackPhase = ''
          runHook preUnpack
          mkdir -p source
          ${pkgs.lib.getExe pkgs.gnutar} -zxf $src -C source
          cd source/package
          runHook postUnpack
        '';

        installPhase = ''
          runHook preInstall
          install -Dm755 bladebro $out/bin/bladebro
          runHook postInstall
        '';

        meta = with pkgs.lib; {
          description = "Stealthy agentic browser driver for AI agents";
          homepage = "https://github.com/dondai44423/bladebro";
          license = licenses.asl20;
          sourceProvenance = with sourceTypes; [ binaryNativeCode ];
          platforms = builtins.attrNames platformAttrs;
          mainProgram = "bladebro";
        };
      };
    };
}
