{ inputs, ... }:
{
  flake.homeModules.nushell =
    {
      username,
      pkgs,
      lib,
      hostname,
      config,
      ...
    }:
    let
      linuxHome = if username == "root" then "/root" else "/home/${username}";
      opencodeApiKeySecret = ../../../secrets/opencode-api-key.age;
      hasOpencodeApiKeySecret = builtins.pathExists opencodeApiKeySecret;
      readOpencodeApiKeyScript =
        if hasOpencodeApiKeySecret then
          pkgs.writeShellScript "read-opencode-api-key" ''
            set -euo pipefail
            cat "${config.age.secrets.opencode-api-key.path}"
          ''
        else
          null;
      mercuryAiToken = ../../../secrets/mercury-ai-token.age;
      hasMercuryAiTokenSecret = builtins.pathExists mercuryAiToken;
      readMercuryAiTokenScript =
        if hasMercuryAiTokenSecret then
          pkgs.writeShellScript "read-mercury-ai-token" ''
            set -euo pipefail
            cat "${config.age.secrets.mercury-ai-token.path}"
          ''
        else
          null;
    in
    {
      imports = [ inputs.agenix.homeManagerModules.default ];

      age.secrets = {
        opencode-api-key.file = lib.mkIf hasOpencodeApiKeySecret opencodeApiKeySecret;
        mercury-ai-token.file = lib.mkIf hasMercuryAiTokenSecret mercuryAiToken;
      };

      programs.nushell = {
        enable = true;
        configFile.source = ./config/config.nu;
        envFile.source = ./config/env.nu;
        # To order the extra config after zoxide with default (1000)
        extraConfig = lib.mkOrder 1100 (
          (builtins.readFile ./config/extra.nu)
          + (lib.optionalString (hostname == "Droid") ''
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
          '')
          + lib.optionalString hasOpencodeApiKeySecret ''

            # opencode-api-key.age: one line, raw API key (no OPENCODE_API_KEY= prefix)
            # Bash expands agenix paths (e.g. $(getconf DARWIN_USER_TEMP_DIR)/agenix/… and ''${XDG_RUNTIME_DIR}/agenix/…) like HM activation.
            $env.OPENCODE_API_KEY = (
              try {
                (^${readOpencodeApiKeyScript} | str trim)
              } catch {
                ""
              }
            )
            $env.MERCURY_AI_TOKEN = (
              try {
                (^${readMercuryAiTokenScript} | str trim)
              } catch {
                ""
              }
            )
          ''
        );
        environmentVariables = lib.mkMerge [
          {
            NH_OS_FLAKE = lib.mkIf pkgs.stdenv.isLinux "${linuxHome}/NixConfig";
            NH_DARWIN_FLAKE = lib.mkIf pkgs.stdenv.isDarwin "/Users/${username}/NixConfig#darwinConfigurations.MacMini";
            DEVELOPER_DIR = lib.mkIf pkgs.stdenv.isDarwin "/Applications/Xcode.app/Contents/Developer";
          }
          # pi-lens (packages from pi-coding-agent home module)
          {
            PILENS_DATA_DIR = "${config.home.homeDirectory}/.pi-lens/projects";
          }
          # pi-markdown-preview (packages from pi-coding-agent home module)
          {
            PANDOC_PATH = lib.getExe pkgs.pandoc;
            MERMAID_CLI_PATH = lib.getExe pkgs.mermaid-cli;
            PANDOC_PDF_ENGINE = "xelatex";
          }
          (lib.mkIf pkgs.stdenv.isDarwin {
            # nixpkgs chromium is unsupported on darwin — Homebrew casks on MacMini
            PUPPETEER_EXECUTABLE_PATH =
              if builtins.pathExists "/Applications/Chromium.app" then
                "/Applications/Chromium.app/Contents/MacOS/Chromium"
              else
                "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome";
          })
          (lib.mkIf (!pkgs.stdenv.isDarwin) {
            PUPPETEER_EXECUTABLE_PATH = lib.getExe pkgs.chromium;
          })
        ];
      };
    };
}
