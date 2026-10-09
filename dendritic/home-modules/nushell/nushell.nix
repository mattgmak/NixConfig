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
      # Explicit list: config.age.secrets also holds non-env secrets.
      envSecrets = {
        OPENCODE_API_KEY = "opencode-api-key";
        MERCURY_AI_TOKEN = "mercury-ai-token";
        CONTEXT7_API_KEY = "context7-api-key";
        GITHUB_MCP_TOKEN = "github-mcp-token";
        OPENROUTER_API_KEY = "openrouter-api-key";
        CURSOR_API_KEY = "cursor-api-key";
        CLINE_API_KEY = "cline-api-key";
        CURSOR_USAGE_SESSION_TOKEN = "cursor-usage-session-token";
        DEEPSEEK_API_KEY = "deepseek-api-key";
      };
      secretFile = name: ../../../secrets/${name}.age;
      availableSecrets = lib.filterAttrs (_: name: builtins.pathExists (secretFile name)) envSecrets;
      secretNames = builtins.attrValues availableSecrets;
      secretPathOf = name: config.age.secrets.${name}.path;
      # Every secret file holds one line, the raw value (no `ENV=` prefix). Bash
      # expands agenix paths (e.g. $(getconf DARWIN_USER_TEMP_DIR)/agenix/… and ''${XDG_RUNTIME_DIR}/agenix/…) like HM activation.
      readSecret = name: pkgs.writeShellScript "read-${name}" ''
        set -euo pipefail
        cat "${secretPathOf name}"
      '';
      # agenix symlinks the generation only after decrypting every secret, so
      # the first present secret doubles as the readiness probe.
      waitAgenixScript =
        if secretNames == [ ] then
          null
        else
          pkgs.writeShellScript "wait-for-agenix" ''
            for _ in {1..200}; do
              if [ -r "${secretPathOf (builtins.head secretNames)}" ]; then exit 0; fi
              sleep 0.05
            done
          '';
    in
    {
      imports = [ inputs.agenix.homeManagerModules.default ];

      # Also declared in zsh/zsh.nix (identical values merge).
      age.secrets = lib.genAttrs secretNames (name: {
        file = secretFile name;
      });

      # Servers (root user): decrypt headless with the passphrase-less SSH host
      # key; desktop users keep the default ~/.ssh identities.
      age.identityPaths = lib.mkIf (config.home.username == "root") [
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
              let temp_dir = try { $nu.temp-dir } catch { $nu.temp-path }
              let ssh_agent_file = (
                $temp_dir | path join $"ssh-agent-(whoami).nuon"
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
          + lib.optionalString (waitAgenixScript != null) ''

            # A shell started before the mount cached empty values for the whole
            # session; wait for agenix instead of reading too early.
            try { ^${waitAgenixScript} } catch { }
          ''
          + lib.concatStringsSep "" (
            lib.mapAttrsToList (env: name: ''

              # ${name}.age: one line, raw value (no ${env}= prefix)
              $env.${env} = (
                try {
                  (^${readSecret name} | str trim)
                } catch {
                  ""
                }
              )
            '') availableSecrets
          )
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
            DEVELOPER_DIR = lib.mkIf pkgs.stdenv.isDarwin "/Applications/Xcode.app/Contents/Developer";
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
