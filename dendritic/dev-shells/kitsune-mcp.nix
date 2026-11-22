# Kitsune MCP dev shell: `nix develop ~/NixConfig#kitsune-mcp`.
# Puts the kitsune MCP server on PATH and exports KITSUNE_MCP_JSON, a mcp.json
# a project links as .pi/mcp.json so pi picks up the server per project.
{
  perSystem =
    { pkgs, system, config, ... }:
    # Plain Nix `if`, not lib.mkIf: flake-parts does not unwrap mkIf.
    if !(builtins.elem system [ "x86_64-linux" "aarch64-darwin" ]) then
      { }
    else
      {
        devShells.kitsune-mcp = pkgs.mkShell {
          packages = [ config.packages.kitsune ];
          KITSUNE_MCP_JSON = pkgs.writeText "kitsune-mcp.json" (
            builtins.toJSON {
              mcpServers.kitsune.command = "${config.packages.kitsune}/bin/kitsune";
            }
          );
          shellHook = ''
            echo "kitsune on PATH; mcp.json at $KITSUNE_MCP_JSON"
            echo "link it: mkdir -p .pi && ln -sf \"$KITSUNE_MCP_JSON\" .pi/mcp.json"
          '';
        };
      };
}
