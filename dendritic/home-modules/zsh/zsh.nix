{ inputs, ... }:
{
  flake.homeModules.zsh =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      # Explicit list: config.age.secrets also holds non-env secrets.
      envSecrets = {
        OPENCODE_API_KEY = "opencode-api-key";
        OPENROUTER_API_KEY = "openrouter-api-key";
        MERCURY_AI_TOKEN = "mercury-ai-token";
        CONTEXT7_API_KEY = "context7-api-key";
        GITHUB_MCP_TOKEN = "github-mcp-token";
        CURSOR_API_KEY = "cursor-api-key";
        CLINE_API_KEY = "cline-api-key";
        CURSOR_USAGE_SESSION_TOKEN = "cursor-usage-session-token";
        DEEPSEEK_API_KEY = "deepseek-api-key";
        COMMAND_CODE_API_KEY = "commandcode-api-key";
      };
      secretFile = name: ../../../secrets/${name}.age;
      availableSecrets = lib.filterAttrs (_: name: builtins.pathExists (secretFile name)) envSecrets;
      secretNames = builtins.attrValues availableSecrets;
      secretPathOf = name: config.age.secrets.${name}.path;
    in
    {
      imports = [ inputs.agenix.homeManagerModules.default ];

      # Also declared in nushell/nushell.nix (identical values merge).
      age.secrets = lib.genAttrs (builtins.attrValues availableSecrets) (name: {
        file = secretFile name;
      });

      # root: decrypt headless with the host key, no ~/.ssh identities.
      age.identityPaths = lib.mkIf (config.home.username == "root") [
        "/etc/ssh/ssh_host_ed25519_key"
      ];

      programs.zsh = {
        enable = true;
        dotDir = "${config.xdg.configHome}/zsh";
        enableCompletion = true; # carapace and fzf-tab need compinit
        completionInit = ''
          autoload -Uz compinit
          _zdump="$ZDOTDIR/.zcompdump-$(printf %s $fpath | md5sum | cut -d' ' -f1)"
          if [[ -f $_zdump ]]; then
            compinit -C -d $_zdump
          else
            compinit -d $_zdump
          fi
          unset _zdump
        '';
        defaultKeymap = "viins"; # nu: edit_mode = vi
        autocd = true;
        autosuggestion.enable = true;
        syntaxHighlighting.enable = true;
        zsh-abbr.enable = true;

        history = {
          size = 100000;
          save = 100000;
          ignoreAllDups = true;
          share = true;
          # zsh globs (HM joins them into HISTORY_IGNORE).
          ignorePatterns = [
            "pi \"*"
            "pi '*"
          ];
        };

        shellAliases = {
          c = "command clear";
          q = "exit";
          s = "sesh connect $(sesh list --icons | fzf --ansi)";
        };

        sessionVariables = {
          EDITOR = "nvim";
        };

        # Secrets are read per shell start, not through sessionVariables: HM
        # wraps those exports in an exported __HM_ZSH_SESS_VARS_SOURCED
        # once-guard, so a shell that started before agenix finished mounting
        # exported empty values and every descendant (tmux server, panes, nu)
        # inherited them for good. .zshenv is unguarded and runs for every zsh.
        # The poll covers the async launchd mount: agenix only flips the
        # generation symlink after decrypting every secret.
        envExtra =
          lib.optionalString (secretNames != [ ]) ''
            if [[ -o interactive ]]; then
              __agenix_first="${secretPathOf (builtins.head secretNames)}"
              for __i in {1..300}; do
                if [[ -r "$__agenix_first" ]]; then break; fi
                sleep 0.01
              done
              unset __agenix_first __i
            fi
          ''
          + lib.concatStringsSep "\n" (
            lib.mapAttrsToList (
              env: name: ''export ${env}="$(cat "${secretPathOf name}" 2>/dev/null)"''
            ) availableSecrets
          );

        # Nix-on-Droid starts the app's login zsh non-interactive (fd0 is a pts
        # but isatty fails under proot, so zsh skips .zshrc and renders no
        # prompt). Marker is only present on nix-on-droid, so other hosts skip.
        profileExtra = ''
          if [[ -e "$HOME/.nix-profile/etc/profile.d/nix-on-droid-session-init.sh" && ! -o interactive && "$(readlink /proc/$$/fd/0)" == /dev/pts/* && -z "$_NOD_REEXEC" ]]; then
            export _NOD_REEXEC=1
            exec zsh -l -i
          fi
        '';

        # Priorities: 570 compinit · 851 zoxide · 910 fzf · 1200 syntax
        # highlighting; integrations with no order set (atuin, carapace, direnv,
        # lazygit, yazi, starship, …) all share 1000.
        initContent = lib.mkMerge [
          # Else vi mode inits at first precmd, after fzf, and takes ^R back.
          (lib.mkOrder 545 "ZVM_INIT_MODE=sourcing")

          # Hand-sourced so vi mode is installed before fzf/atuin bind keys.
          (lib.mkOrder 600 ''
            source ${pkgs.zsh-vi-mode}/share/zsh-vi-mode/zsh-vi-mode.plugin.zsh
          '')

          # After compinit and fzf: captures the then-current ^I widget.
          (lib.mkOrder 915 ''
            source ${pkgs.zsh-fzf-tab}/share/fzf-tab/fzf-tab.plugin.zsh

            zstyle ':completion:*' menu no
            zstyle ':completion:*:descriptions' format '[%d]'
            zstyle ':completion:*' list-colors ''${(s.:.)LS_COLORS}
          '')

          (lib.mkOrder 1050 (builtins.readFile ./config/init.zsh))
        ];
      };

      # agenix only decrypts from a systemd user service, which nix-on-droid has
      # no way to run (Android, no systemd); decrypt at activation instead. The
      # identity is the device's own ~/.ssh/id_ed25519 — the Droid recipient.
      home.activation.agenixMount = lib.mkIf (config.home.username == "nix-on-droid") (
        lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          run mkdir -m 700 -p ${config.age.secretsDir}
          ${lib.concatStringsSep "\n" (
            lib.mapAttrsToList (_: secret: ''
              run ${pkgs.age}/bin/age --decrypt --identity "$HOME/.ssh/id_ed25519" -o "${secret.path}.tmp" ${secret.file}
              run chmod ${secret.mode} "${secret.path}.tmp"
              run mv -f "${secret.path}.tmp" "${secret.path}"
            '') config.age.secrets
          )}
        ''
      );

      programs.atuin.flags = [ "--disable-ctrl-r" ];

      programs.fzf = {
        enable = true;
        enableZshIntegration = true;
      };

      programs.lazygit = {
        enableZshIntegration = true;
        shellWrapperName = "l";
      };
    };
}
