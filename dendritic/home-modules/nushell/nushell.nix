{
  flake.homeModules.nushell =
    {
      username,
      pkgs,
      lib,
      hostname,
      ...
    }:
    let
      linuxHome = if username == "root" then "/root" else "/home/${username}";
    in
    {
      programs.nushell = {
        enable = true;
        configFile.source = ./config/config.nu;
        envFile.source = ./config/env.nu;
        # To order the extra config after zoxide with default (1000)
        extraConfig = lib.mkOrder 1100 (( builtins.readFile ./config/extra.nu ) + ( lib.optionalString ( hostname == "Droid" ) ''
          do --env {
            let ssh_agent_file = (
              $nu.temp-path | path join $"ssh-agent-(whoami).nuon"
            )
            if ($ssh_agent_file | path exists) {
              let ssh_agent_env = open ($ssh_agent_file)
              if ($"/proc/($ssh_agent_env.SSH_AGENT_PID)" | path exists) {
                load-env $ssh_agent_env
                return
              } else {
                rm $ssh_agent_file
              }
            }
            let ssh_agent_env = ^ssh-agent -c
              | lines
              | first 2
              | parse "setenv {name} {value};"
              | transpose --header-row
              | into record
            load-env $ssh_agent_env
            $ssh_agent_env | save --force $ssh_agent_file
          }
  '' ));
        environmentVariables = {
          NH_OS_FLAKE = lib.mkIf pkgs.stdenv.isLinux "${linuxHome}/NixConfig";
          NH_DARWIN_FLAKE = lib.mkIf pkgs.stdenv.isDarwin "/Users/${username}/NixConfig#darwinConfigurations.MacMini";
          DEVELOPER_DIR = lib.mkIf pkgs.stdenv.isDarwin "/Applications/Xcode.app/Contents/Developer";
        };
      };
    };
}
