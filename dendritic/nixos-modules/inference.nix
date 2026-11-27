# Inference stack for Strix Halo: llama-swap proxies the Halogen stacks, gufo serves ASR and decisions.
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

      asrModel = "${modelsDir}/Qwen3-ASR-1.7B";

      # d1 answers packed decision questions and never generates text. The
      # projector carries the vision tower, so text and image requests share it.
      d1Model = "${modelsDir}/d1/d1-Omni-2B-Q8_0.gguf";
      d1Mmproj = "${modelsDir}/d1/mmproj-d1-Omni-2B-BF16.gguf";

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

          # The Halogen containers own the graphics memory. These peers only
          # appear in the model list while the container that serves them runs.
          peers = {
            halogen-signal = {
              proxy = "http://127.0.0.1:8731";
              models = [ "halogen-flash-next-signal-abliterated" ];
            };
            halogen-thinkingcap = {
              proxy = "http://127.0.0.1:8751";
              models = [ "halogen-flash-next-thinkingcap-abliterated" ];
            };
          };

          # Peers list under peer/model. A pin selector gives the clean id.
          # unlisted keeps that id off /v1/models, so each model shows once.
          selectors = {
            halogen-flash-next-signal-abliterated = {
              strategy = "pin";
              unlisted = true;
              targets = [ "halogen-signal/halogen-flash-next-signal-abliterated" ];
            };
            halogen-flash-next-thinkingcap-abliterated = {
              strategy = "pin";
              unlisted = true;
              targets = [ "halogen-thinkingcap/halogen-flash-next-thinkingcap-abliterated" ];
            };
          };
        };
      };

      # The weight fetch is a long oneshot. Hanging it off multi-user.target
      # makes every switch wait for the download chain, so this target reaches
      # after multi-user.target and activation returns first. Check progress
      # with `systemctl status inference.target`.
      systemd.targets.inference = {
        description = "Inference stack";
        wantedBy = [ "multi-user.target" ];
        unitConfig.After = [ "multi-user.target" ];
      };

      systemd.services.llama-swap = {
        wantedBy = lib.mkForce [ "inference.target" ];
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
          # Each HIP process opens hardware queues of its own. Above eight
          # compute queues on the box the iGPU stays 100% busy at idle, so every
          # spawned model caps itself at one.
          Environment = [ "GPU_MAX_HW_QUEUES=1" ];
        };
      };

      # mkGufoServe drops --mmproj and --context outside the llm modality, so
      # this unit spells the command out. It serves only /v1/systemone, and
      # llama-swap routes by model name, so llama-swap cannot front it. The
      # queue cap below keeps the unit cheap to hold.
      systemd.services.gufo-decide = {
        description = "gufo decision (d1-Omni-2B)";
        wantedBy = [ "inference.target" ];
        after = [
          "network.target"
          "gufo-models.service"
        ];
        wants = [ "gufo-models.service" ];
        serviceConfig = {
          Type = "exec";
          ExecStart = "${pkgs.gufo}/bin/gufo serve --host 127.0.0.1 --port 8182 decision --model ${d1Model} --mmproj ${d1Mmproj} --context 8192 --served-model-name d1-omni-2b";
          Restart = "on-failure";
          RestartSec = 5;

          DynamicUser = true;
          CacheDirectory = "gufo-decide";
          SupplementaryGroups = [
            "render"
            "video"
          ];
          LimitMEMLOCK = "infinity";
          Environment = [ "GPU_MAX_HW_QUEUES=1" ];
          PrivateDevices = false;
          PrivateUsers = false;
          ProtectHome = true;
          ProtectSystem = "strict";
          PrivateTmp = true;
          NoNewPrivileges = true;
          WorkingDirectory = "/tmp";
        };
      };

      systemd.services.gufo-asr = {
        description = "gufo ASR (Qwen3-ASR-1.7B)";
        wantedBy = [ "inference.target" ];
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
          Environment = [ "GPU_MAX_HW_QUEUES=1" ];
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
