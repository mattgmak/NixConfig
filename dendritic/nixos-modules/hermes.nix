# Hermes Agent on Ramsay. Native mode, no dedicated hermes user. The main
# tenant runs as user agent with root /home/agent/hermes, so it reaches the
# NixConfig checkout and every worktree without a sudo wrapper. Local models
# run through llama-swap on 127.0.0.1:9292. The firewall drops the LAN and trusts
# tailscale0, so every port here is tailnet-only. The Gateway API binds 8642
# for REST and the backend binds 9119 for the dashboard routes and the
# /api/ws JSON-RPC transport. The webui binds loopback. Tailscale serve
# publishes the webui and the API on 443 and the dashboard on 8443. A second
# tenant — user hermes-alt, root /var/lib/hermes-alt — mirrors the first on
# 8643, 9120 and 8788 as svc:hermes-api-alt and svc:hermes-webui-alt. The HUI+
# bridges bind 8792 (main) and 8791 (alt) on loopback and publish as
# svc:hermes-bridge and svc:hermes-bridge-alt on 443.
{ inputs, ... }:
{
  flake.nixosModules.hermes =
    { config, lib, pkgs, ... }:
    let
      localBaseUrl = "http://127.0.0.1:9292/v1";
      # The flake input pins the release tag. The builder still names the package
      # after its own default, so stamp the tag on the derivation.
      hermesVersion = "0.22.5+canary.20261102T065013Z";
      agentPackage = inputs.hermes-agent.packages.${pkgs.stdenv.hostPlatform.system}.default.overrideAttrs
        (_: {
          version = hermesVersion;
        });

      # The npm package ships the HUI+ skill next to the CLI. hermesHomeFiles takes
      # one entry per file, so list every regular file of the skill dir: SKILL.md
      # plus the references/ level. The alt seed script links the same dir.
      hermesUiSkillDir =
        "${pkgs.hermesUiPlusBridge}/lib/node_modules/hermes-ui-plus-bridge/skill/hermes-ui";
      hermesUiSkillFiles =
        let
          regularFiles =
            dir: builtins.attrNames (
              lib.filterAttrs (_: type: type == "file") (builtins.readDir dir)
            );
          refFiles = lib.optionals (builtins.pathExists "${hermesUiSkillDir}/references") (
            map (name: "references/${name}") (regularFiles "${hermesUiSkillDir}/references")
          );
        in
        lib.listToAttrs (
          map (
            name: {
              name = "skills/hermes-ui/${name}";
              value = "${hermesUiSkillDir}/${name}";
            }
          ) ((regularFiles hermesUiSkillDir) ++ refFiles)
        );

      # The alt tenant. A second user owns a second root, so the agent account
      # has no path into the private profile. The module holds one option set, so
      # these units copy the native unit shape by hand.
      altStateDir = "/var/lib/hermes-alt";
      altProfileHome = "${altStateDir}/.hermes/profiles/private";
      # The module's own renderers, so the alt config.yaml and .env match the
      # shape the package expects, including the _config_version stamp.
      altCommon = import (inputs.hermes-agent + "/nix/moduleCommon.nix") {
        inherit lib;
      };
      # The main gateway holds 8642, and api_server.py reads extra.port before
      # the API_SERVER_PORT env var, so both sources carry 8643 here. The CORS
      # list names the alt origins because the main list rejects them.
      altEnvironment = builtins.removeAttrs config.services.hermes-agent.environment [
        "API_SERVER_CORS_ORIGINS"
      ] // {
        API_SERVER_PORT = "8643";
        API_SERVER_CORS_ORIGINS = "https://hermes-api-alt.dab-octatonic.ts.net,https://hermes-webui-alt.dab-octatonic.ts.net";
      };
      altAgentCfg = {
        environment = altEnvironment;
        package = agentPackage;
        # gateway.standalone keeps the alt gateway out of the main gateway's
        # multiplexer, which is the one rule host_attach.py allows a second
        # gateway to break.
        settings = lib.recursiveUpdate config.services.hermes-agent.settings {
          gateway.standalone = true;
          platforms.api_server.extra.port = 8643;
          # The alt plugin needs its own port and secret. The main plugin holds
          # 8646, and the main secret belongs to another user.
          plugins.entries.hermes-ui-plus.settings.server.port = 8647;
          plugins.entries.hermes-ui-plus.settings.server.secret_file = config.age.secrets."hui-plugin-secret-alt".path;
          # The main config points the Dashboard link at the main dashboard, so
          # the alt config needs its own URL.
          webui.dashboard.url = "https://hermes-api-alt.dab-octatonic.ts.net:8443";
        };
        configFile = null;
        extraPythonPackages = [ ];
        extraDependencyGroups = [ ];
        environmentFiles = [ config.age.secrets."hermes-env-alt".path ];
      };
      altConfigFiles = altCommon.mkConfigFiles {
        inherit pkgs;
        cfg = altAgentCfg;
        workingDirectory = "${altStateDir}/workspace";
      };
      altEnvScript = altCommon.mkEnvScript {
        inherit pkgs;
        environment = altEnvironment;
      };
      # comma resolves a bare command name from the nix-index database at
      # ~/.cache/nix-index/files. Each gateway sets HOME to its own state dir, so
      # link the database file into both state dirs. `packages.<system>.default`
      # is the nix-index binary; `nix-index-database` is the index itself.
      nixIndexDb =
        inputs.nix-index-database.packages.${pkgs.stdenv.hostPlatform.system}.nix-index-database;
    in
    {
      imports = [
        inputs.hermes-agent.nixosModules.default
        inputs.hermes-webui.nixosModules.default
      ];

      age.secrets."hermes-env" = {
        file = ../../secrets/hermes-env.age;
        mode = "0400";
      };
      # The alt tenant reads its own credentials, so the two gateways never hold
      # one bot token at the same time.
      age.secrets."hermes-env-alt" = {
        file = ../../secrets/hermes-env-alt.age;
        mode = "0400";
      };
      # HUI+ plugin secrets. The plugin accepts only mode 0600 or 0640, so each
      # tenant owns one file. The matching bridge reads that same file.
      age.secrets."hui-plugin-secret" = {
        file = ../../secrets/hui-plugin-secret.age;
        mode = "0600";
        owner = "agent";
      };
      age.secrets."hui-plugin-secret-alt" = {
        file = ../../secrets/hui-plugin-secret-alt.age;
        mode = "0600";
        owner = "hermes-alt";
      };

      systemd.tmpfiles.rules = [
        # /var/lib/hermes stays reachable as a symlink to the new state dir.
        "L+ /var/lib/hermes - - - - /home/agent/hermes"
        "d /home/agent/hermes/.cache 0700 agent agent - -"
        "d /home/agent/hermes/.cache/nix-index 0700 agent agent - -"
        "L+ /home/agent/hermes/.cache/nix-index/files - - - - ${nixIndexDb}"
        "d /var/lib/hermes-alt/.cache 0700 hermes-alt hermes-alt - -"
        "d /var/lib/hermes-alt/.cache/nix-index 0700 hermes-alt hermes-alt - -"
        "L+ /var/lib/hermes-alt/.cache/nix-index/files - - - - ${nixIndexDb}"
      ];

      services.hermes-agent = {
        enable = true;
        package = agentPackage;
        # The agent account owns /home/agent and the NixConfig checkout, so the
        # gateway needs no ACL grant and no sudo wrapper to open a worktree.
        user = "agent";
        group = "agent";
        createUser = false;
        stateDir = "/home/agent/hermes";
        # pi for coding work, and the Hermes user skill that teaches it to call
        # pi as a subagent. See dendritic/packages/pi-local.nix.
        # ramsayDeploy holds the deploy scripts. See
        # dendritic/packages/ramsay-deploy.nix. git is on the PATH because the
        # deploy skill inspects the clone with plain git commands.
        # nix and comma reach any nixpkgs tool: `nix run nixpkgs#<pkg>` and
        # `comma <cmd>`. nix-daemon.socket is 0666, so an unprivileged unit can
        # use the daemon. lean-ctx is the CLI behind the context engine plugin.
        # The agent's install check names ripgrep, node, npm, and ffmpeg.
        # Without them every start warns "install out of sync".
        extraPackages = [
          pkgs.piLocal
          pkgs.ramsayDeploy
          pkgs.git
          pkgs.nix
          pkgs.comma
          pkgs.lean-ctx
          pkgs.ripgrep
          pkgs.nodejs
          pkgs.ffmpeg
        ];
        # types.package takes a derivation or a top-level store path. The nested
        # vendor path fails that check, and its builtins.path form trips
        # parseDrvName on newer Nix, so the plugin dir ships as a small
        # derivation. Hermes links it as plugins/nix-managed-<name>.
        extraPlugins = [
          (pkgs.stdenv.mkDerivation {
            pname = "hermes-lean-ctx";
            version = "0.1.0";
            src = ../../vendor/mattgmak/lean-ctx/integrations/hermes-lean-ctx;
            dontUnpack = true;
            installPhase = ''
              runHook preInstall
              mkdir -p $out
              cp -r --no-preserve=mode $src/. $out/
              runHook postInstall
            '';
          })
          # plugin.yaml names this plugin hermes-ui-plus. The npm bridge package
          # ships no plugin dir, so the source comes from the vendored repo.
          (pkgs.stdenv.mkDerivation {
            pname = "hermes-ui-plus";
            version = "0.3.0";
            src = ../../vendor/robbyczgw-cla/hermes-ui-plus/hermes-plugin/hermes_ui_plus;
            dontUnpack = true;
            installPhase = ''
              runHook preInstall
              mkdir -p $out
              cp -r --no-preserve=mode $src/. $out/
              runHook postInstall
            '';
          })
        ];
        hermesHomeFiles = {
          "skills/pi/SKILL.md" = ./hermes-skills/pi/SKILL.md;
          "skills/deploy/SKILL.md" = ./hermes-skills/deploy/SKILL.md;
          "skills/nixconfig-worktree/SKILL.md" = ./hermes-skills/nixconfig-worktree/SKILL.md;
        } // hermesUiSkillFiles;
        settings = {
          # The deploy gate. `manual` asks the owner on every flagged call, and
          # the mode stays here so the agent cannot reach the bypass keys.
          # `off` and YOLO return approved before the gate in tools/approval.py.
          approvals = {
            mode = "manual";
            timeout = 300;
            unattended_mode = "deny";
            cron_mode = "deny";
            single_query_mode = "deny";
            # A raw root route must never reach a prompt. These match before
            # YOLO and before `mode: off`. The sudoers wrapper is the only path.
            deny = [
              "*nh os switch*"
              "*nh os boot*"
              "*nixos-rebuild*"
              "*sudo -i*"
              "*sudo -s*"
              "*sudo su*"
            ];
          };
          security.approval = {
            transport = "builtin";
            transport_fallback = "deny";
          };
          # The gate: block any call that names the switch wrapper unless a
          # live approval token exists. Hermes drops the `approve` directive in
          # its exec worker, so `block` is the only directive that holds.
          # `fail_closed` blocks the call when the hook crashes or times out.
          hooks_auto_accept = true;
          hooks.pre_tool_call = [
            {
              matcher = "terminal|execute_code";
              command = "${pkgs.ramsayDeploy}/bin/ramsay-gate";
              timeout = 15;
              fail_closed = true;
            }
          ];
          model = {
            provider = "custom";
            default = "halogen-flash-next-signal-abliterated";
            base_url = localBaseUrl;
            context_length = 131072;
          };
          # The active context engine. lean-ctx replaces the built-in
          # ContextCompressor, so the compression.* keys below stay inert until
          # this reverts to "compressor".
          context.engine = "lean-ctx";
          # extraPlugins installs the plugin dir, and the webui shows it Disabled
          # until its name joins this list. `hermes plugins enable` writes the same
          # key into config.yaml.
          plugins.enabled = [ "hermes-lean-ctx" "hermes-ui-plus" ];
          # HUI+ settings. The main gateway keeps port 8646, and the bridge points
          # at the same agenix secret. expose_memory lets paired devices read
          # MEMORY.md and USER.md.
          plugins.entries.hermes-ui-plus.settings = {
            server.port = 8646;
            server.secret_file = config.age.secrets."hui-plugin-secret".path;
            library.expose_memory = true;
          };
          # Built-in compressor tuning. A sub-512K window floors threshold at
          # 0.75, so compaction fires at 98304 tokens here. protect_first_n = 0
          # keeps only the system prompt plus the rolling summary, and three real
          # user turns stay verbatim so bulky tool output cannot evict them.
          compression = {
            enabled = true;
            threshold = 0.75;
            min_tail_user_messages = 3;
            protect_first_n = 0;
            hygiene_max_turn_hold_seconds = 300;
            proactive_prune_tokens = 48000;
          };
          # The summariser inherits the resident model (provider "auto"), so
          # llama-swap never swaps for a compaction call. context_length pins the
          # real 131072 window instead of the 200000 default, which is what sizes
          # the summary. The 300s timeout covers a local model's latency.
          auxiliary.compression = {
            provider = "auto";
            model = "";
            base_url = "";
            context_length = 131072;
            timeout = 300;
          };
          # The webui reads this from the same config.yaml. Without it the
          # Dashboard link points at the loopback probe URL.
          webui.dashboard = {
            enabled = "always";
            url = "https://hermes-api.dab-octatonic.ts.net:8443";
          };
          # Every id below is on the llama-swap /v1/models list. The aliases
          # let a running session switch with /model <name>.
          model_aliases = {
            halogen-flash-next-v2-abliterated = {
              model = "halogen-flash-next-v2-abliterated";
              provider = "custom";
              base_url = localBaseUrl;
            };
            gufo-flash-next = {
              model = "gufo-flash-next";
              provider = "custom";
              base_url = localBaseUrl;
            };
            gufo-flash-next-uncensored-abliterated = {
              model = "gufo-flash-next-uncensored-abliterated";
              provider = "custom";
              base_url = localBaseUrl;
            };
            gufo-flash-next-uncensored-abliterated-bench = {
              model = "gufo-flash-next-uncensored-abliterated-bench";
              provider = "custom";
              base_url = localBaseUrl;
            };
            gufo-flash-next-swift = {
              model = "gufo-flash-next-swift";
              provider = "custom";
              base_url = localBaseUrl;
            };
          };
        };
        environment = {
          API_SERVER_ENABLED = "true";
          API_SERVER_HOST = "0.0.0.0";
          # The API server answers 403 to any request that carries an Origin
          # header while this list stays empty.
          API_SERVER_CORS_ORIGINS = "https://hermes-api.dab-octatonic.ts.net,https://ramsay.dab-octatonic.ts.net";
          # lean-ctx engine settings. The plugin reads its whole config from this
          # namespace (config.py), and the port is the `lean-ctx serve` tools API,
          # not the LLM proxy. update_model() overrides the window on model
          # switch, so the value here only covers the start of a session.
          # CORE_COMPACTION and ENABLE_TOOLS stay off: both need the `leanctx`
          # Python SDK in the sealed venv, and nixpkgs has no python3Packages
          # entry for it. Add it through extraPythonPackages, then flip both to 1
          # and point a `lean-ctx serve` instance at 8080 for the agent account.
          # With them off, the engine runs its own Python compaction.
          LEANCTX_BASE_URL = "http://127.0.0.1:8080";
          LEANCTX_CONTEXT_LENGTH = "131072";
          LEANCTX_THRESHOLD_FRACTION = "0.75";
          LEANCTX_CORE_COMPACTION = "0";
          LEANCTX_ENABLE_TOOLS = "0";
        };
        environmentFiles = [ config.age.secrets."hermes-env".path ];
        # A non-loopback dashboard bind refuses to start without a registered
        # auth provider. The bundled basic plugin registers once its
        # credentials reach $HERMES_HOME/.env from the secret below.
        # A 0.0.0.0 bind makes the Host guard accept every name, so the
        # dashboard works on the MagicDNS name and through a proxy.
        # "serve" sets HERMES_SERVE_HEADLESS=1 and never serves the browser
        # SPA. "dashboard" is serve plus the SPA, and keeps /api/ws.
        backend = {
          mode = "dashboard";
          host = "0.0.0.0";
          port = 9119;
        };
      };

      # The agent account runs these wrappers directly, so the fixed-argv sudo
      # rules for user hermes are gone. The agent's own rules in
      # hosts/Ramsay.nix still cover `ramsay-deploy-approve` and
      # `ramsay-deploy-switch`, and the root-owned token keeps the gate honest.
      # The NixConfig mirror and clone go away with the hermes user: the deploy
      # scripts now read /home/agent/NixConfig, the one checkout.
      environment.systemPackages = [
        pkgs.createWorktree
        pkgs.ramsayDeploy
        pkgs.spawnApprovalSession
      ];

      services.hermes-webui = {
        enable = true;
        user = "agent";
        group = "agent";
        host = "127.0.0.1";
        hermesHome = "${config.services.hermes-agent.stateDir}/.hermes";
        agent.package = agentPackage;
        environmentFiles = [ config.age.secrets."hermes-env".path ];
        # The webui venv ships no `gateway` Python package, so its agent health
        # probe finds no local signal and shows "Gateway not configured". An
        # explicit API URL switches the probe to HTTP against this gateway.
        extraEnvironment = { HERMES_API_URL = "http://127.0.0.1:8642"; };
      };

      # The alt tenant owns its own user and root. The agent account holds
      # /home/agent/hermes at 2770, so a file there stays unreadable for
      # hermes-alt, and a file in /var/lib/hermes-alt stays unreadable for agent.
      users.groups.hermes-alt = { };
      users.users.hermes-alt = {
        isSystemUser = true;
        group = "hermes-alt";
        home = altStateDir;
        createHome = true;
        homeMode = "0700";
        shell = pkgs.bashInteractive;
        # The gateway dispatches cron through `systemd-run --user`, which needs a
        # user manager for this uid.
        linger = true;
      };

      # The module builds config.yaml and .env only for the single stateDir, so
      # this unit seeds the alt profile home from the same Nix sources.
      systemd.services.hermes-alt-home = {
        description = "Seed the alt Hermes profile home";
        wantedBy = [ "multi-user.target" ];
        before = [ "hermes-agent-alt.service" "hermes-webui-alt.service" ];
        path = [ pkgs.coreutils ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        script = ''
          root=${altStateDir}
          home=${altProfileHome}
          mkdir -p "$root" "$root/.hermes" "$home" "$root/workspace" "$root/webui"
          for d in cron sessions logs memories plugins; do
            mkdir -p "$home/$d"
          done
          # The alt config selects context.engine = "lean-ctx", which the plugin
          # provides. The main agent links the same set as nix-managed-<name>.
          for p in ${toString config.services.hermes-agent.extraPlugins}; do
            ln -sfn "$p" "$home/plugins/nix-managed-$(basename "$p")"
          done
          # The HUI+ skill ships inside the bridge package, so link the store dir.
          mkdir -p "$home/skills"
          ln -sfn ${hermesUiSkillDir} "$home/skills/hermes-ui"
          chown -R hermes-alt:hermes-alt "$root"
          chmod 700 "$root" "$root/.hermes" "$home"
          install -o hermes-alt -g hermes-alt -m 0640 -D \
            ${altConfigFiles.effective} "$home/config.yaml"
          ${altEnvScript} "$home/.env" 0640 ${config.age.secrets."hermes-env-alt".path}
          chown hermes-alt:hermes-alt "$home/.env"
        '';
      };

      # The alt gateway. The profile marks itself standalone, so host_attach.py
      # lets it coexist with the multiplexing gateway on the main user.
      systemd.services.hermes-agent-alt = {
        description = "Hermes Agent Gateway (alt profile)";
        wantedBy = [ "multi-user.target" ];
        after = [
          "network-online.target"
          "linger-users.service"
          "hermes-alt-home.service"
        ];
        wants = [ "network-online.target" "linger-users.service" ];
        unitConfig.Requires = [ "hermes-alt-home.service" ];
        path = [
          agentPackage
          pkgs.bash
          pkgs.coreutils
          pkgs.git
          pkgs.nix
          pkgs.comma
          pkgs.lean-ctx
        ];
        environment = {
          HOME = altStateDir;
          HERMES_HOME = altProfileHome;
          HERMES_MANAGED = "true";
        };
        # loginctl returns before user@<uid>.service finishes, and the gateway
        # resolves the user bus once at startup. Bounded and non-fatal.
        preStart = ''
          for _ in $(seq 1 50); do
            [ -S "/run/user/$(id -u)/bus" ] && break
            sleep 0.2
          done
        '';
        serviceConfig = {
          User = "hermes-alt";
          Group = "hermes-alt";
          WorkingDirectory = "${altStateDir}/workspace";
          ExecStart = "${agentPackage}/bin/hermes gateway";
          Restart = "always";
          RestartSec = 5;
          UMask = "0007";
          NoNewPrivileges = true;
          ProtectSystem = "strict";
          ProtectHome = false;
          ReadWritePaths = [ altStateDir "${altStateDir}/workspace" ];
          PrivateTmp = true;
        };
      };

      # The alt backend. The module builds one backend unit, so this unit copies
      # the generated shape with the alt user, the alt home, and port 9120. The
      # 0.0.0.0 bind keeps the Host guard open for the MagicDNS name, the same
      # reason the main backend binds 0.0.0.0.
      systemd.services.hermes-backend-alt = {
        description = "Hermes Agent web dashboard and desktop backend (alt profile)";
        after = [ "network-online.target" "hermes-agent-alt.service" ];
        wants = [ "network-online.target" ];
        wantedBy = [ "multi-user.target" ];
        unitConfig.Requires = [ "hermes-agent-alt.service" ];
        path = [
          agentPackage
          pkgs.bash
          pkgs.coreutils
          pkgs.git
          pkgs.nix
          pkgs.comma
          pkgs.lean-ctx
        ];
        environment = {
          HOME = altStateDir;
          HERMES_HOME = altProfileHome;
          HERMES_MANAGED = "true";
        };
        serviceConfig = {
          User = "hermes-alt";
          Group = "hermes-alt";
          WorkingDirectory = "${altStateDir}/workspace";
          ExecStart = "${agentPackage}/bin/hermes dashboard --host 0.0.0.0 --port 9120 --no-open";
          Restart = "always";
          RestartSec = 5;
          UMask = "0007";
          NoNewPrivileges = true;
          ProtectSystem = "strict";
          ProtectHome = false;
          ReadWritePaths = [ altStateDir "${altStateDir}/workspace" ];
          PrivateTmp = true;
        };
      };

      # The alt webui. HERMES_HOME points at the profile home and
      # ISOLATED_PROFILE pins it, so this instance never offers the main profile.
      # Cookie names differ from the first instance because browsers key cookies
      # by host, not port, so both ports on one host share a cookie jar.
      systemd.services.hermes-webui-alt = {
        description = "Hermes Web UI (alt profile)";
        after = [ "network-online.target" "hermes-agent-alt.service" ];
        wants = [ "network-online.target" ];
        wantedBy = [ "multi-user.target" ];
        unitConfig.Requires = [ "hermes-agent-alt.service" ];
        serviceConfig = {
          Type = "simple";
          User = "hermes-alt";
          Group = "hermes-alt";
          ExecStart = "${config.services.hermes-webui.package}/bin/hermes-webui";
          Restart = "on-failure";
          Environment = [
            "HERMES_WEBUI_HOST=127.0.0.1"
            "HERMES_WEBUI_PORT=8788"
            "HERMES_WEBUI_STATE_DIR=${altStateDir}/webui"
            "HERMES_HOME=${altProfileHome}"
            "HERMES_WEBUI_ISOLATED_PROFILE=private"
            "HERMES_WEBUI_DEFAULT_WORKSPACE=${altStateDir}/workspace"
            "HERMES_WEBUI_COOKIE_NAME=hermes_webui_alt_session"
            "HERMES_WEBUI_PROFILE_COOKIE_NAME=hermes_profile_alt"
            "HERMES_WEBUI_PYTHON=${agentPackage.passthru.hermesVenv}/bin/python3"
            "HERMES_API_URL=http://127.0.0.1:8643"
          ];
          EnvironmentFile = [ config.age.secrets."hermes-env-alt".path ];
          UMask = "0077";
        };
      };

      # The HUI+ bridge is the companion of the Hermes UI+ app. It proxies the
      # Hermes API, so the API key never leaves the host, serves the web bundle,
      # and keeps its own token and state in BRIDGE_STATE_DIR. The bridge reads
      # HERMES_API_KEY, while the secret exports API_SERVER_KEY, so ExecStart
      # copies the value into the name the bridge reads.
      systemd.services.hermes-ui-bridge = {
        description = "Hermes UI+ bridge (main)";
        after = [ "network-online.target" "hermes-agent.service" ];
        wants = [ "network-online.target" ];
        wantedBy = [ "multi-user.target" ];
        unitConfig.Requires = [ "hermes-agent.service" ];
        serviceConfig = {
          Type = "simple";
          User = "agent";
          Group = "agent";
          Restart = "on-failure";
          RestartSec = 5;
          UMask = "0077";
          Environment = [
            "HERMES_BASE_URL=http://127.0.0.1:8642"
            "HERMES_HOME=/home/agent/hermes/.hermes"
            "BRIDGE_PUBLIC_URL=https://hermes-bridge.dab-octatonic.ts.net"
            "BRIDGE_STATE_DIR=/home/agent/.local/state/hermes-ui-bridge"
            "BRIDGE_HERMES_PLUGIN_URL=http://127.0.0.1:8646"
            "BRIDGE_HERMES_PLUGIN_SECRET_FILE=${config.age.secrets."hui-plugin-secret".path}"
          ];
          EnvironmentFile = [ config.age.secrets."hermes-env".path ];
          ExecStart = "${pkgs.bash}/bin/bash -c 'HERMES_API_KEY=\"$API_SERVER_KEY\" exec ${pkgs.hermesUiPlusBridge}/bin/hermes-ui-plus-bridge --port 8792'";
        };
      };

      # The alt tenant runs its own bridge on 8791 against the alt API, so the two
      # HUI+ sessions stay separate. The alt secret holds its own API_SERVER_KEY.
      systemd.services.hermes-ui-bridge-alt = {
        description = "Hermes UI+ bridge (alt profile)";
        after = [ "network-online.target" "hermes-agent-alt.service" ];
        wants = [ "network-online.target" ];
        wantedBy = [ "multi-user.target" ];
        unitConfig.Requires = [ "hermes-agent-alt.service" ];
        serviceConfig = {
          Type = "simple";
          User = "hermes-alt";
          Group = "hermes-alt";
          Restart = "on-failure";
          RestartSec = 5;
          UMask = "0077";
          Environment = [
            "HERMES_BASE_URL=http://127.0.0.1:8643"
            "HERMES_HOME=/var/lib/hermes-alt/.hermes/profiles/private"
            "BRIDGE_PUBLIC_URL=https://hermes-bridge-alt.dab-octatonic.ts.net"
            "BRIDGE_STATE_DIR=/var/lib/hermes-alt/.local/state/hermes-ui-bridge"
            "BRIDGE_HERMES_PLUGIN_URL=http://127.0.0.1:8647"
            "BRIDGE_HERMES_PLUGIN_SECRET_FILE=${config.age.secrets."hui-plugin-secret-alt".path}"
          ];
          EnvironmentFile = [ config.age.secrets."hermes-env-alt".path ];
          ExecStart = "${pkgs.bash}/bin/bash -c 'HERMES_API_KEY=\"$API_SERVER_KEY\" exec ${pkgs.hermesUiPlusBridge}/bin/hermes-ui-plus-bridge --port 8791'";
        };
      };

      systemd.services.tailscale-serve-hermes = lib.mkIf config.services.tailscale.enable {
        description = "Tailscale serve for the Hermes web UI and API";
        after = [
          "tailscaled.service"
          "hermes-webui.service"
          "hermes-webui-alt.service"
          "hermes-agent.service"
          "hermes-agent-alt.service"
          "hermes-backend.service"
          "hermes-backend-alt.service"
          "hermes-ui-bridge.service"
          "hermes-ui-bridge-alt.service"
        ];
        wants = [ "tailscaled.service" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        path = [
          config.services.tailscale.package
          pkgs.coreutils
          pkgs.jq
        ];
        script = ''
          for _ in $(seq 1 30); do
            if tailscale status &>/dev/null; then
              break
            fi
            sleep 2
          done

          tailscale serve --yes --service=svc:hermes-webui --https=443 127.0.0.1:8787
          tailscale serve --yes --service=svc:hermes-webui-alt --https=443 127.0.0.1:8788
          tailscale serve --yes --service=svc:hermes-api --https=443 127.0.0.1:8642
          # The app builds the dashboard URL from its one host field and a port.
          # Over HTTPS it reuses the gateway port, so the dashboard needs a
          # second HTTPS port on the same service. Set Dashboard Port to 8443.
          tailscale serve --yes --service=svc:hermes-api --https=8443 127.0.0.1:9119
          tailscale serve --yes --service=svc:hermes-api-alt --https=443 127.0.0.1:8643
          tailscale serve --yes --service=svc:hermes-api-alt --https=8443 127.0.0.1:9120
          tailscale serve --yes --service=svc:hermes-bridge --https=443 127.0.0.1:8792
          tailscale serve --yes --service=svc:hermes-bridge-alt --https=443 127.0.0.1:8791
        '';
      };
    };
}
