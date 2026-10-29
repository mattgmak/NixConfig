{
  flake.cursorMcp = {
    mcpServers = {
      nixos = {
        command = "mcp-nixos";
      };
      Linear = {
        url = "https://mcp.linear.app/mcp";
        headers = { };
      };
    };
  };
}
