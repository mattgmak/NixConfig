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

      # Gufo discovers the other three shards from the first one.
      flashNextModel = "${modelsDir}/Qwen3.8-Flash-Next-UD-Q4_K_XL-00001-of-00004.gguf";
      flashNextMtp = "${modelsDir}/mtp-Qwen3.8-Flash-Next-shared-Q8_0.gguf";

      # The uncensored projector repeats the stock base name, so it lives in a
      # subdirectory and both paths below stay explicit.
      uncensoredDir = "${modelsDir}/uncensored";
      uncensoredModel = "${uncensoredDir}/Qwen3.8-Flash-Next-Uncensored-Gufo-Q4Mix.gguf";
      uncensoredMmproj = "${uncensoredDir}/mmproj-BF16.gguf";
      uncensoredMtp = "${uncensoredDir}/Qwen3.8-Flash-CIRU-STRIX-Orca-MTP-Q8_0.gguf";

      qwen27bModel = "${modelsDir}/Qwen3.8-27B-UD-Q4_K_XL.gguf";
      qwen27bDraft = "${modelsDir}/Qwen3.8-27B-DFlash2-Q4_K_M.gguf";
      asrModel = "${modelsDir}/Qwen3-ASR-1.7B";

      # The Swift requant and its projector live in a subdir, because gufo picks
      # a sibling mmproj by base name.
      swiftModel = "${modelsDir}/swift/Swift-1.5-Qwen3.8-Flash-Next-UD-Q4_K_XL-00001-of-00005.gguf";
      swiftMmproj = "${modelsDir}/swift/mmproj-BF16.gguf";

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
                extraArgs = [ "--mmproj" "${modelsDir}/mmproj-BF16.gguf" ];
              };
              useModelName = "flash-next";
              ttl = 300;
              checkEndpoint = "/ready";
              aliases = [ "qwen3.8-flash-next" ];
            };

            "flash-next-uncensored" = {
              cmd = gufoServe {
                modality = "llm";
                model = uncensoredModel;
                port = "\${PORT}";
                servedModelName = "flash-next-uncensored";
                speculative = "mtp";
                mtpModel = uncensoredMtp;
                sessions = 2;
                context = 131072;
                extraArgs = [
                  "--mmproj"
                  uncensoredMmproj
                ];
              };
              useModelName = "flash-next-uncensored";
              ttl = 300;
              checkEndpoint = "/ready";
              aliases = [ "qwen3.8-flash-next-uncensored" ];
            };

            # Swift 1.5 keeps the shared Unsloth MTP head and cuts thinking
            # tokens. It is the resident default: 51 tok/s decode beats stock.
            "flash-next-swift" = {
              cmd = gufoServe {
                modality = "llm";
                model = swiftModel;
                port = "\${PORT}";
                servedModelName = "flash-next-swift";
                speculative = "mtp";
                mtpModel = flashNextMtp;
                sessions = 2;
                context = 131072;
                extraArgs = [ "--mmproj" swiftMmproj ];
              };
              useModelName = "flash-next-swift";
              # 0 = never unload: this set stays resident.
              ttl = 0;
              checkEndpoint = "/ready";
              aliases = [ "qwen3.8-flash-next-swift" ];
            };

            # Only flash-next and Qwen3.8-27B are gufo model families. The
            # earlier Coder-30B pick is unsupported upstream.
            "qwen3.8-27b" = {
              cmd = gufoServe {
                modality = "llm";
                model = qwen27bModel;
                port = "\${PORT}";
                servedModelName = "qwen3.8-27b";
                speculative = "dflash2";
                dflashModel = qwen27bDraft;
                sessions = 2;
                context = 65536;
              };
              useModelName = "qwen3.8-27b";
              ttl = 300;
              checkEndpoint = "/ready";
              aliases = [ "qwen27b" ];
            };
          };

          hooks.on_startup.preload = [ "flash-next-swift" ];

          routing.router.settings.groups = {
            # All models share one group: about 104G of weights leaves no room
            # for a second KV cache. swap makes them evict each other. ttl 0 on
            # flash-next-swift keeps it loaded while idle.
            gpu = {
              swap = true;
              exclusive = false;
              persistent = false;
              members = [
                "flash-next"
                "flash-next-uncensored"
                "flash-next-swift"
                "qwen3.8-27b"
              ];
            };
          };
        };
      };

      # The weight fetch and the Swift requant are long oneshots. Hanging them
      # off multi-user.target makes every switch wait for the download chain:
      # a 175 GiB fetch cost 41 minutes on 2026-10-30. This target reaches after
      # multi-user.target, so activation returns and the stack comes up behind
      # it. Check progress with `systemctl status inference.target`.
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
