{ ... }:
{
  perSystem =
    { pkgs, ... }:
    let
      version = "0.8.1";
      # nixpkgs mcp 2.x renamed FastMCP; kitsune pins mcp>=1.2,<2. Same
      # override pi-coding-agent applies to mcp-nixos.
      python = pkgs.python3Packages.overrideScope (
        final: _: { mcp = final.mcp_1; }
      );
      kitsune-pkg = python.buildPythonApplication {
        pname = "kitsune-browser";
        inherit version;
        format = "pyproject";
        src = python.fetchPypi {
          inherit version;
          # The sdist file is kitsune_browser-0.8.1.tar.gz; fetchPypi derives the
          # filename from pname.
          pname = "kitsune_browser";
          hash = "sha256-im8LkCCRkxihRGeoyqx4upGJItzpDXH60rpycEFXmdc=";
        };
        build-system = with python; [ hatchling ];
        dependencies = with python; [
          httpx
          pydantic
          websockets
          mcp_1
        ];
        pythonImportsCheck = [ "kitsune" ];
      };
      # Interpreter that carries kitsune plus its propagated deps, so the wrapper
      # resolves imports without hand-listing site-packages.
      interpreter = python.python.withPackages (_: [ kitsune-pkg ]);
    in
    {
      # The `kitsune` server binary. The root wheel ships only kitsune-bridge;
      # the MCP entry point lives in packages/kitsune-browser-mcp, so wrap the
      # module directly.
      packages.kitsune = pkgs.runCommand "kitsune-${version}" {
        nativeBuildInputs = [ pkgs.makeWrapper ];
      } ''
        mkdir -p $out/bin
        makeWrapper ${interpreter}/bin/python $out/bin/kitsune \
          --add-flags "-m kitsune.server"
      '';

      # Unpacked extension zipped with manifest.json at the zip root, the form
      # Firefox's ExtensionSettings install_url accepts. The dev variant keeps
      # browser_js code Mozilla forbids in signed builds.
      packages.kitsune-extension = pkgs.stdenvNoCC.mkDerivation {
        pname = "kitsune-extension";
        inherit version;
        src = ../../vendor/junyeong-nero/kitsune;
        sourceRoot = ".";
        nativeBuildInputs = [ pkgs.zip ];
        phases = [ "installPhase" ];
        installPhase = ''
          runHook preInstall
          mkdir -p $out/share/kitsune
          cd $src/extension
          zip -qr $out/share/kitsune/kitsune-extension.zip .
          runHook postInstall
        '';
      };
    };
}
