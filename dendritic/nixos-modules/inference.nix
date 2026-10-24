# Inference stack for Strix Halo: llama-swap routes the LLMs, gufo serves ASR.
# Both bind loopback only. Tailscale serve publishes them on the tailnet.
{ inputs, ... }:
{
  flake.nixosModules.inference =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      modelsDir = "/var/lib/inference/models";

      # Gufo discovers the other eight shards from the first one.
      flashNextModel = "${modelsDir}/Qwen3.8-Flash-Next-IQ4_NL-PROJFIX-00001-of-00009.gguf";
      flashNextMtp = "${modelsDir}/mtp-Qwen3.8-Flash-Next-shared-Q8_0.gguf";

      coderModel = "${modelsDir}/Qwen3-Coder-30B-A3B-Instruct-Q4_K_M.gguf";
      asrModel = "${modelsDir}/Qwen3-ASR-1.7B";

      # Upstream helper: same flags as the CLI, so no flag name is retyped here.
      gufoServe = args: inputs.gufo.lib.mkGufoServe ({ gufo = pkgs.gufo; } // args);
    in
    {
      services.llama-swap = {
        enable = true;
        listenAddress = "127.0.0.1";
        port = 9292;

        settings = {
          healthCheckTimeout = 1200;
          globalTTL = 0;
          logToStdout = "both";

          models = {
            "flash-next" = {
              cmd = gufoServe {
                modality = "llm";
                model = flashNextModel;
                port = "\${PORT}";
                servedModelName = "flash-next";
                speculative = "mtp";
                mtpModel = flashNextMtp;
                sessions = 2;
                context = 131072;
              };
              useModelName = "flash-next";
              # 0 = never unload: this set stays resident.
              ttl = 0;
              checkEndpoint = "/ready";
              aliases = [ "qwen3.8-flash-next" ];
            };

            "coder-30b" = {
              cmd = gufoServe {
                modality = "llm";
                model = coderModel;
                port = "\${PORT}";
                servedModelName = "coder-30b";
                sessions = 2;
                context = 65536;
              };
              useModelName = "coder-30b";
              ttl = 300;
              checkEndpoint = "/ready";
              aliases = [ "qwen3-coder-30b-a3b" ];
            };
          };

          hooks.on_startup.preload = [ "flash-next" ];

          routing.router.settings.groups = {
            # Both models come from one group: 96G of weights plus 17G of coder
            # leaves no room for a second KV cache. swap makes them evict each
            # other. ttl 0 on flash-next still keeps it loaded while idle.
            gpu = {
              swap = true;
              exclusive = false;
              persistent = false;
              members = [
                "flash-next"
                "coder-30b"
              ];
            };
          };
        };
      };

      systemd.services.llama-swap = {
        after = [ "gufo-models.service" ];
        wants = [ "gufo-models.service" ];
        serviceConfig = {
          # The upstream unit maps its own user namespace, which hides the owner
          # of /dev/kfd and /dev/dri/renderD* from the ROCm runtime.
          PrivateUsers = lib.mkForce false;
          SupplementaryGroups = [
            "render"
            "video"
          ];
          LimitMEMLOCK = "infinity";
        };
      };

      systemd.services.gufo-asr = {
        description = "gufo ASR (Qwen3-ASR-1.7B)";
        wantedBy = [ "multi-user.target" ];
        after = [
          "network.target"
          "gufo-models.service"
        ];
        wants = [ "gufo-models.service" ];
        serviceConfig = {
          Type = "exec";
          ExecStart = gufoServe {
            modality = "asr";
            model = asrModel;
            host = "127.0.0.1";
            port = 8181;
            context = 1024;
            servedModelName = "qwen3-asr-1.7b";
          };
          Restart = "on-failure";
          RestartSec = 5;

          DynamicUser = true;
          CacheDirectory = "gufo-asr";
          SupplementaryGroups = [
            "render"
            "video"
          ];
          LimitMEMLOCK = "infinity";
          PrivateDevices = false;
          PrivateUsers = false;
          ProtectHome = true;
          ProtectSystem = "strict";
          PrivateTmp = true;
          NoNewPrivileges = true;
          WorkingDirectory = "/tmp";
        };
      };

      # caddy.nix owns the other tailnet services. These two belong to inference.
      systemd.services.tailscale-serve-inference = lib.mkIf config.services.tailscale.enable {
        description = "Tailscale serve for the inference endpoints";
        after = [ "tailscaled.service" ];
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

          # Stale entry from the retired llama.cpp setup. "off" exits 1 when the
          # service is already gone, so check the serve state first.
          stale=svc:llama-cpp
          if tailscale serve status --json 2>/dev/null \
            | jq -e --arg s "$stale" '[.Services[$s].Web // {} | keys[] | select(endswith(":443"))] | length > 0' >/dev/null; then
            tailscale serve --yes --service="$stale" --https=443 off
          fi

          tailscale serve --yes --service=svc:inference --https=443 127.0.0.1:9292
          tailscale serve --yes --service=svc:asr --https=443 127.0.0.1:8181
        '';
      };
    };
}
