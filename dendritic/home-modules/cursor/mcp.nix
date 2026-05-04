{
  flake.cursorMcp = {
    mcpServers = {
      nixos = {
        command = "nix run github:utensils/mcp-nixos --";
      };
      context7 = {
        url = "https://mcp.context7.com/mcp";
      };
      Linear = {
        url = "https://mcp.linear.app/mcp";
        headers = { };
      };
    };
  };
}
