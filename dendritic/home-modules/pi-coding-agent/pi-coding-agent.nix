{ inputs, lib, ... }:
{
  flake.homeModules.pi-coding-agent =
    { config, pkgs, ... }:
    let
      repoRoot = "${config.home.homeDirectory}/NixConfig/dendritic";
      piAgentRoot = "${repoRoot}/home-modules/pi-coding-agent";
    in
    {
      imports = [ inputs.coding-agents.homeManagerModules.default ];

      coding-agents = {
        skillsDir = lib.mkDefault "${repoRoot}/skills";
        pi-coding-agent = {
          enable = lib.mkDefault true;
          extensionsDir = lib.mkDefault "${piAgentRoot}/extensions";
          promptsDir = lib.mkDefault "${piAgentRoot}/prompts";
        };
      };

      home.packages = with pkgs; [
        nodejs_22
        ffmpeg
        uv
        bun
      ];

      home.file.".pi/agent/themes".source = config.lib.file.mkOutOfStoreSymlink "${piAgentRoot}/themes";
      home.file.".pi/agent/models.json".source =
        config.lib.file.mkOutOfStoreSymlink "${piAgentRoot}/models.json";
      home.file.".pi/agent/mcp.json".source =
        config.lib.file.mkOutOfStoreSymlink "${piAgentRoot}/mcp.json";
    };
}
