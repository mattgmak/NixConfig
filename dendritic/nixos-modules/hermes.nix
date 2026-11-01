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
      agentPackage = inputs.hermes-agent.packages.${pkgs.stdenv.hostPlatform.system}.default;
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
          # The gate itself: escalate any call that names the switch wrapper.
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
          if [ -d "$src/.git" ]; then
            [ -d "$mirror" ] || git init --bare --quiet --shared=group "$mirror"
            git -C "$src" -c safe.directory="$src" push --quiet --force \
              "$mirror" HEAD:refs/heads/main || true
            chgrp -R ${config.services.hermes-agent.group} "$mirror"
            chmod -R g+rX "$mirror"
          fi
          [ -d "$mirror/refs/heads/main" ] || [ -f "$mirror/packed-refs" ] || exit 0
          if [ -d "$target/.git" ]; then
            # The first clone took /root/NixConfig as origin. Move it here.
            git -C "$target" -c safe.directory="$target" remote set-url origin "$mirror"
            exit 0
          fi
          rm -rf "$target.partial"
          git clone --recurse-submodules --quiet "$mirror" "$target.partial"
          mv "$target.partial" "$target"
          chown -R ${config.services.hermes-agent.user}:${config.services.hermes-agent.group} "$target"
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
