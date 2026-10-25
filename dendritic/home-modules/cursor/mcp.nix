{
  flake.cursorMcp = {
    mcpServers = {
      nixos = {
        command = "nix run github:utensils/mcp-nixos --";
      };
      Linear = {
        url = "https://mcp.linear.app/mcp";
        headers = { };
      };
    };
  };
}
