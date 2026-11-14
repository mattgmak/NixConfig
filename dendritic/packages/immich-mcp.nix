{ ... }:
{
  perSystem =
    { pkgs, ... }:
    let
      pname = "immich-mcp";
      # The sdist is immich_mcp-0.5.7.tar.gz; fetchPypi derives the filename from pname.
      pypiName = "immich_mcp";
      version = "0.5.7";
      python = pkgs.python3Packages.python;
    in
    {
      packages.immich-mcp = pkgs.python3Packages.buildPythonApplication {
        inherit pname version;
        format = "pyproject";
        src = pkgs.python3Packages.fetchPypi {
          pname = pypiName;
          inherit version;
          hash = "sha256-XRm+cq8n79Ns1i2TPRCmYvF92DoqOTSRcKSdH3drYs8=";
        };
        build-system = with pkgs.python3Packages; [
          hatchling
          uv-dynamic-versioning
        ];
        dependencies = with pkgs.python3Packages; [
          mcp
          gunicorn
          uvicorn
        ];
        pythonImportsCheck = [ "immich_mcp" ];
        # The wheel has no entry_points.txt, so upstream ships no console script.
        # server.py holds the `__main__` guard, so wrap it as `immich-mcp`.
        nativeBuildInputs = [ pkgs.makeWrapper ];
        postInstall = ''
          mkdir -p $out/bin
          makeWrapper ${python}/bin/python $out/bin/immich-mcp \
            --set PYTHONPATH $out/${python.sitePackages} \
            --add-flags "-m immich_mcp.server"
        '';
      };
    };
}
