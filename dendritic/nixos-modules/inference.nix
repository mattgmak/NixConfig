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

      asrModel = "${modelsDir}/Qwen3-ASR-1.7B";

      # 1.72 GB Q8_0 text checkpoint. Weights plus an 8192-token FP32 KV cache
      # cost about 3 GiB, which fits the pool beside halogen.
      lfm3Model = "${modelsDir}/lfm3/LFM3-1.7B-Q8_0.gguf";

      # d1 answers packed decision questions and never generates text. The
      # projector carries the vision tower, so text and image requests share it.
      d1Model = "${modelsDir}/d1/d1-Omni-2B-Q8_0.gguf";
      d1Mmproj = "${modelsDir}/d1/mmproj-d1-Omni-2B-BF16.gguf";

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
            "gufo-flash-next" = {
              cmd = gufoServe {
                modality = "llm";
                model = flashNextModel;
                port = "\${PORT}";
                servedModelName = "gufo-flash-next";
                speculative = "mtp";
                mtpModel = flashNextMtp;
                sessions = 2;
                context = 131072;
                extraArgs = [ "--mmproj" "${modelsDir}/mmproj-BF16.gguf" ];
              };
              useModelName = "gufo-flash-next";
              ttl = 300;
              checkEndpoint = "/ready";
            };

            "gufo-flash-next-uncensored-abliterated" = {
              cmd = gufoServe {
                modality = "llm";
                model = uncensoredModel;
                port = "\${PORT}";
                servedModelName = "gufo-flash-next-uncensored-abliterated";
                speculative = "mtp";
                mtpModel = uncensoredMtp;
                sessions = 2;
                context = 131072;
                extraArgs = [
                  "--mmproj"
                  uncensoredMmproj
                ];
              };
              useModelName = "gufo-flash-next-uncensored-abliterated";
              ttl = 300;
              checkEndpoint = "/ready";
            };

            # Same weights as gufo-flash-next-uncensored-abliterated with a small KV
            # footprint. The refusal probe sends short prompts and froze the box
            # at 131072.
            "gufo-flash-next-uncensored-abliterated-bench" = {
              cmd = gufoServe {
                modality = "llm";
                model = uncensoredModel;
                port = "\${PORT}";
                servedModelName = "gufo-flash-next-uncensored-abliterated-bench";
                speculative = "mtp";
                mtpModel = uncensoredMtp;
                sessions = 1;
                context = 32768;
                extraArgs = [
                  "--mmproj"
                  uncensoredMmproj
                ];
              };
              useModelName = "gufo-flash-next-uncensored-abliterated-bench";
              ttl = 300;
              checkEndpoint = "/ready";
            };

            # Swift 1.5 keeps the shared Unsloth MTP head and cuts thinking
            # tokens: 51 tok/s decode beats stock.
            "gufo-flash-next-swift" = {
              cmd = gufoServe {
                modality = "llm";
                model = swiftModel;
                port = "\${PORT}";
                servedModelName = "gufo-flash-next-swift";
                speculative = "mtp";
                mtpModel = flashNextMtp;
                sessions = 2;
                context = 131072;
                extraArgs = [ "--mmproj" swiftMmproj ];
              };
              useModelName = "gufo-flash-next-swift";
              ttl = 300;
              checkEndpoint = "/ready";
            };

            # Autoname and OM calls stay on the cloud or the halogen peer, so
            # this model loads only on demand. A cold load costs 80 to 130 s
            # under halogen load, and the ttl keeps the wait rare. The RAM
            # checkpoint cache is capped, because the default takes half of free
            # RAM at 4.7 GiB per process.
            "lfm3-1.7b" = {
              cmd = gufoServe {
                modality = "llm";
                model = lfm3Model;
                port = "\${PORT}";
                servedModelName = "lfm3-1.7b";
                sessions = 1;
                context = 8192;
                think = "off";
                extraArgs = [
                  "--cache-ram-bytes"
                  "536870912"
                ];
              };
              useModelName = "lfm3-1.7b";
              ttl = 1800;
              checkEndpoint = "/ready";
            };
          };

          # The Halogen containers own the graphics memory. These peers only
          # appear in the model list while the container that serves them runs.
          peers = {
            halogen-signal = {
              proxy = "http://127.0.0.1:8731";
              models = [ "halogen-flash-next-signal-abliterated" ];
            };
            halogen-abliter-v2 = {
              proxy = "http://127.0.0.1:8741";
              models = [ "halogen-flash-next-v2-abliterated" ];
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
            halogen-flash-next-v2-abliterated = {
              strategy = "pin";
              unlisted = true;
              targets = [ "halogen-abliter-v2/halogen-flash-next-v2-abliterated" ];
            };
          };

          routing.router.settings.groups = {
            # All gufo models share one group: about 104G of weights leaves no
            # room for a second KV cache. swap makes them evict each other.
            gpu = {
              swap = true;
              exclusive = false;
              persistent = false;
              members = [
                "gufo-flash-next"
                "gufo-flash-next-uncensored-abliterated"
                "gufo-flash-next-uncensored-abliterated-bench"
                "gufo-flash-next-swift"
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

      # mkGufoServe drops --mmproj and --context outside the llm modality, so
      # this unit spells the command out. Only /v1/systemone is served.
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
