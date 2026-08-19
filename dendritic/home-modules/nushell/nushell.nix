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
      context7ApiKeySecret = ../../../secrets/context7-api-key.age;
      hasContext7ApiKeySecret = builtins.pathExists context7ApiKeySecret;
      readContext7ApiKeyScript =
        if hasContext7ApiKeySecret then
          pkgs.writeShellScript "read-context7-api-key" ''
            set -euo pipefail
            cat "${config.age.secrets.context7-api-key.path}"
          ''
        else
          null;
      githubMcpTokenSecret = ../../../secrets/github-mcp-token.age;
      hasGithubMcpTokenSecret = builtins.pathExists githubMcpTokenSecret;
      readGithubMcpTokenScript =
        if hasGithubMcpTokenSecret then
          pkgs.writeShellScript "read-github-mcp-token" ''
            set -euo pipefail
            cat "${config.age.secrets.github-mcp-token.path}"
          ''
        else
          null;
      cursorApiKeySecret = ../../../secrets/cursor-api-key.age;
      hasCursorApiKeySecret = builtins.pathExists cursorApiKeySecret;
      readCursorApiKeyScript =
        if hasCursorApiKeySecret then
          pkgs.writeShellScript "read-cursor-api-key" ''
            set -euo pipefail
            cat "${config.age.secrets.cursor-api-key.path}"
          ''
        else
          null;
    in
    {
      imports = [ inputs.agenix.homeManagerModules.default ];

      age.secrets = {
        opencode-api-key.file = lib.mkIf hasOpencodeApiKeySecret opencodeApiKeySecret;
        mercury-ai-token.file = lib.mkIf hasMercuryAiTokenSecret mercuryAiToken;
        context7-api-key.file = lib.mkIf hasContext7ApiKeySecret context7ApiKeySecret;
        github-mcp-token.file = lib.mkIf hasGithubMcpTokenSecret githubMcpTokenSecret;
        cursor-api-key.file = lib.mkIf hasCursorApiKeySecret cursorApiKeySecret;
      };

      # Servers (root user): decrypt headless with the passphrase-less SSH host
      # key; desktop users keep the default ~/.ssh identities.
      age.identityPaths = lib.mkIf (username == "root") [
        "/etc/ssh/ssh_host_ed25519_key"
      ];


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
          + lib.optionalString hasContext7ApiKeySecret ''

            # context7-api-key.age: one line, raw API key (no CONTEXT7_API_KEY= prefix)
            $env.CONTEXT7_API_KEY = (
              try {
                (^${readContext7ApiKeyScript} | str trim)
              } catch {
                ""
              }
            )
          ''
          + lib.optionalString hasGithubMcpTokenSecret ''

            # github-mcp-token.age: one line, raw GitHub PAT (no GITHUB_MCP_TOKEN= prefix)
            $env.GITHUB_MCP_TOKEN = (
              try {
                (^${readGithubMcpTokenScript} | str trim)
              } catch {
                ""
              }
            )
          ''
          + lib.optionalString hasCursorApiKeySecret ''

            # cursor-api-key.age: one line, raw Cursor SDK API key (no CURSOR_API_KEY= prefix)
            $env.CURSOR_API_KEY = (
              try {
                (^${readCursorApiKeyScript} | str trim)
              } catch {
                ""
              }
            )
          ''
          + ''

            # Nushell has no per-command history ignore (0.112 only ships
            # ignore_space_prefixed), so scrub `pi "..."` prompt launches out of
            # history.txt once they are written, before the next prompt shows.
            $env.config.hooks.pre_prompt = (
              $env.config.hooks.pre_prompt?
              | default []
              | append {||
                let history_path = $nu.history-path
                if ($history_path | path exists) {
                  let current = (open --raw $history_path)
                  let cleaned = (
                    $current
                    | lines
                    | where {|line|
                        not (($line | str starts-with 'pi "') or ($line | str starts-with "pi '"))
                      }
                    | str join "\n"
                    | if ($in | is-empty) { $in } else { $in + "\n" }
                  )
                  if $cleaned != $current {
                    $cleaned | save --force $history_path
                  }
                }
              }
            )
          ''
        );
        environmentVariables = lib.mkMerge [
          config.home.sessionVariables
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
