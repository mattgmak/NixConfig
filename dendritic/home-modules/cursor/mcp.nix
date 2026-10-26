let
  # Same pin as pi: the flake URL lives once, in pi-coding-agent/mcp.json.
  piMcp = builtins.fromJSON (builtins.readFile ../pi-coding-agent/mcp.json);
  nixosFlake = builtins.head (
    builtins.filter (arg: builtins.substring 0 7 arg == "github:") piMcp.mcpServers.nixos.args
  );
in
{
  flake.cursorMcp = {
    mcpServers = {
      nixos = {
        command = "nix run ${nixosFlake} --";
      };
      Linear = {
        url = "https://mcp.linear.app/mcp";
        headers = { };
      };
    };
  };
}
