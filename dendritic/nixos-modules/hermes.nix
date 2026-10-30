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
        settings = {
          model = {
            provider = "custom";
            default = "flash-next-uncensored";
            base_url = localBaseUrl;
            context_length = 131072;
          };
          # The webui reads this from the same config.yaml. Without it the
          # Dashboard link points at the loopback probe URL.
          webui.dashboard = {
            enabled = "always";
            url = "https://hermes-api.dab-octatonic.ts.net:8443";
          };
          # llama-swap lists flash-next, flash-next-uncensored, flash-next-swift
          # and qwen3.8-27b on /v1/models. The aliases let a running session
          # switch with /model <name>.
          model_aliases = {
            flash-next = {
              model = "flash-next";
              provider = "custom";
              base_url = localBaseUrl;
            };
            flash-uncensored = {
              model = "flash-next-uncensored";
              provider = "custom";
              base_url = localBaseUrl;
            };
            swift = {
              model = "flash-next-swift";
              provider = "custom";
              base_url = localBaseUrl;
            };
            qwen-27b = {
              model = "qwen3.8-27b";
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
