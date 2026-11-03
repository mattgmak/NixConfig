# Hermes Agent on Ramsay. Native mode, dedicated hermes user, local models
# through llama-swap on 127.0.0.1:9292. The firewall drops the LAN and trusts
# tailscale0, so every port here is tailnet-only. The Gateway API binds 8642
# for REST and the backend binds 9119 for the dashboard routes and the
# /api/ws JSON-RPC transport. The webui binds loopback. Tailscale serve
# publishes the webui and the API on 443 and the dashboard on 8443.
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
      services.hermes-agent = {
        enable = true;
        package = agentPackage;
        # pi for coding work, and the Hermes user skill that teaches it to call
        # pi as a subagent. See dendritic/packages/pi-local-hermes.nix.
        # ramsayDeploy holds the deploy scripts. See
        # dendritic/packages/ramsay-deploy.nix. git is on the PATH because the
        # deploy skill inspects the clone with plain git commands.
        extraPackages = [
          pkgs.piLocalHermes
          pkgs.ramsayDeploy
          pkgs.git
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
        ];
        hermesHomeFiles = {
          "skills/pi/SKILL.md" = ./hermes-skills/pi/SKILL.md;
          "skills/deploy/SKILL.md" = ./hermes-skills/deploy/SKILL.md;
        };
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
          # and point a `lean-ctx serve` instance at 8080 for the hermes user.
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

      # The sudoers rule needs a fixed argv, so the switch wrapper sits at the
      # one stable name. The rule allows that name, with no arguments.
      environment.systemPackages = [ pkgs.ramsayDeploy ];

      security.sudo.extraRules = [
        {
          users = [ "hermes" ];
          commands = [
            {
              command = "/run/current-system/sw/bin/ramsay-deploy-switch";
              options = [ "NOPASSWD" ];
            }
          ];
        }
      ];

      # Hermes needs a writable clone. /root/NixConfig stays root-owned, and
      # /home/agent is 0700. A root-owned bare mirror carries the tree that was
      # last switched, and the clone takes its origin from the mirror. Without
      # the mirror, a deploy from a stale clone would roll the machine back.
      systemd.services.hermes-nixconfig = {
        description = "Mirror NixConfig and clone it for the Hermes deploy path";
        wantedBy = [ "multi-user.target" ];
        wants = [ "network-online.target" ];
        after = [ "network-online.target" ];
        before = [ "hermes-agent.service" ];
        path = [
          pkgs.git
          pkgs.coreutils
        ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        script = ''
          src=/home/agent/NixConfig
          mirror=${config.services.hermes-agent.stateDir}/NixConfig.git
          target=${config.services.hermes-agent.stateDir}/NixConfig
          if [ ! -d "$src/.git" ]; then
            echo "hermes-nixconfig: no git tree at $src" >&2
            exit 1
          fi
          [ -d "$mirror" ] || git init --bare --quiet --shared=group "$mirror"
          # The clone tracks the mirror. Do not hide a failed push: a stale
          # origin here lets a later deploy roll the machine back.
          if ! git -C "$src" -c safe.directory="$src" push --quiet --force \
            "$mirror" HEAD:refs/heads/main; then
            echo "hermes-nixconfig: push of $src to $mirror failed" >&2
            exit 1
          fi
          chgrp -R ${config.services.hermes-agent.group} "$mirror"
          chmod -R g+rX "$mirror"
          if [ -d "$target/.git" ]; then
            # The first clone took /root/NixConfig as origin. Move it here.
            git -C "$target" -c safe.directory="$target" remote set-url origin "$mirror"
            echo "hermes-nixconfig: origin of $target set to $mirror"
            exit 0
          fi
          rm -rf "$target.partial"
          git clone --recurse-submodules --quiet "$mirror" "$target.partial"
          mv "$target.partial" "$target"
          chown -R ${config.services.hermes-agent.user}:${config.services.hermes-agent.group} "$target"
          echo "hermes-nixconfig: cloned $target from $mirror"
        '';
      };

      services.hermes-webui = {
        enable = true;
        user = "hermes";
        group = "hermes";
        host = "127.0.0.1";
        hermesHome = "${config.services.hermes-agent.stateDir}/.hermes";
        agent.package = agentPackage;
        environmentFiles = [ config.age.secrets."hermes-env".path ];
      };

      systemd.services.tailscale-serve-hermes = lib.mkIf config.services.tailscale.enable {
        description = "Tailscale serve for the Hermes web UI and API";
        after = [
          "tailscaled.service"
          "hermes-webui.service"
          "hermes-agent.service"
          "hermes-backend.service"
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
          tailscale serve --yes --service=svc:hermes-api --https=443 127.0.0.1:8642
          # The app builds the dashboard URL from its one host field and a port.
          # Over HTTPS it reuses the gateway port, so the dashboard needs a
          # second HTTPS port on the same service. Set Dashboard Port to 8443.
          tailscale serve --yes --service=svc:hermes-api --https=8443 127.0.0.1:9119
        '';
      };
    };
}
