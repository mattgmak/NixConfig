{
  flake.nixosModules.ai =
    { pkgs, ... }:
    {
      # --- llama-swap Service ---
      # Transparent proxy for automatic model swapping with llama.cpp

      environment.etc."llama-swap/config.yaml".text = ''
        # llama-swap configuration
        # This config uses llama.cpp's server to serve models on demand

        models:  # Ordered from newest to oldest

          # Ling-3.0-tiny (7.9B total / 1.3B active MoE, bailingmoe3 arch) — agentic coding.
          # Same MBZUAI-IFM fork serves it (bailingmoe3 supported). Q5_K_M 5.24 GB fits 8GB with
          # ~1.5GB headroom (hybrid KDA+MLA KV is tiny: ~0.3GB @64k) → full GPU offload, fast decode.
          # Q6_K would be ~7.1GB = same spill edge as K2 Q6 (7 tok/s). 128K native ctx.
          # Independent AA: Intelligence 25, Agentic 16.
          # Source: https://huggingface.co/inclusionAI/Ling-3.0-tiny-GGUF
          "ling-3.0-tiny:q5km":
            cmd: |
              ${pkgs.llama-cpp}/bin/llama-server
              -hf inclusionAI/Ling-3.0-tiny-GGUF:Q5_K_M
              --port ''${PORT}
              --jinja
              -ngl 99
              --fit on
              --fit-target 900
              --fit-ctx 4096
              -c 65536
              --parallel 1
              -b 512
              -ub 256
              --flash-attn on
              -ctk q4_0
              -ctv q4_0
              --reasoning on
              --temp 1.0
              --top-p 0.95

          # K2-Horizon-3.7B Q4_K_M (512K native ctx) — agentic coding on RTX 3070 Ti.
          # Served by MBZUAI-IFM llama.cpp fork (model/K2Horizon @ 35999d1); merge base
          # = b10450 so the Qwen3.8 DeltaNet fix (ggml-org#27164) stays in effect.
          # Fit math @64k ctx: KV 2.59 GB (q4_0) + Q4_K_M 2.94 GB + compute ~0.2 GB
          #  ≈ 5.7 GB vs ~6.1 GB usable (8 GB minus sweep-next-edit persistent 1.6 +
          #  desktop 0.7). Q5_K_M + compute 0.3 GB = 6.29 GB OOM'd. -b 256 shrinks pp
          #  buffers; Q4_K_M beats Q4_0 (k-quant). Source: abenzerps/K2-Horizon-3.7B-GGUF
          # Client: reasoning_effort high, temp 1.0, top_p 0.95; allow ≥32k output tokens.
          "k2-horizon:3.7b-q4km":
            cmd: |
              ${pkgs.llama-cpp}/bin/llama-server
              -hf abenzerps/K2-Horizon-3.7B-GGUF:Q4_K_M
              --port ''${PORT}
              --jinja
              -ngl 99
              --fit on
              --fit-target 900
              --fit-ctx 4096
              -c 65536
              --parallel 1
              -b 256
              -ub 128
              --flash-attn on
              -ctk q4_0
              -ctv q4_0
              --reasoning on
              --temp 1.0
              --top-p 0.95

          # Next-edit autocomplete (~1.5 GB Q8), fits fully on RTX 3070 Ti.
          # Source: https://huggingface.co/sweepai/sweep-next-edit-1.5B
          "sweep-next-edit:1.5b-q8":
            cmd: |
              ${pkgs.llama-cpp}/bin/llama-server
              -hf sweepai/sweep-next-edit-1.5B:Q8_0
              --port ''${PORT}
              --ctx-size 8192
              --parallel 2
              --batch-size 512
              --ubatch-size 256
              --flash-attn on

          # MoE 26B A4B (~3.8B active), UD-Q4_K_XL ~17 GB, max ctx: 262144, 30 layers
          # RTX 3070 Ti (8 GB): mostly CPU offload; mmproj via -hf.
          # Source: https://huggingface.co/unsloth/gemma-4-26B-A4B-it-GGUF
          "gemma-4:26b-a4b-q4":
            cmd: |
              ${pkgs.llama-cpp}/bin/llama-server
              -hf unsloth/gemma-4-26B-A4B-it-GGUF:UD-Q4_K_XL
              --port ''${PORT}
              --ctx-size 0
              --fit on
              --fit-target 768
              --fit-ctx 4096
              --parallel 1
              --batch-size 512
              --ubatch-size 256
              --flash-attn on
              --cache-type-k q4_0
              --cache-type-v q4_0
              --jinja

          # Qwen3.8-27B UD-IQ2_XXS on RTX 3070 Ti (8 GB) via mainline llama.cpp b10450.
          # b10450 fixes DeltaNet CUDA garbage (ggml-org#27164).
          # UD-Q2_K_XL / UD-Q4_K_M hybrid CUDA still corrupt; IQ2_XXS + --fit works (~8 tok/s).
          # Hybrid GPU+RAM: --fit offloads layers; default kv-offload spills KV to system RAM.
          # q4_0 KV halves cache size; --cache-ram -1 allows unlimited prompt-cache RAM.
          # --no-mmproj required (vision projector OOMs 8 GB). MTP off until stable.
          # Client: enable_thinking false for routine; medium/xhigh for fragile coding.
          # Source: https://huggingface.co/unsloth/Qwen3.8-27B-GGUF
          "qwen3.8:27b-iq2xxs":
            cmd: |
              ${pkgs.llama-cpp}/bin/llama-server
              -hf unsloth/Qwen3.8-27B-GGUF:UD-IQ2_XXS
              --port ''${PORT}
              --jinja
              --no-mmproj
              --fit on
              --fit-target 512
              --fit-ctx 8192
              -t 12
              -tb 12
              -c 16384
              --parallel 1
              -b 64
              -ub 64
              --flash-attn on
              -ctk q4_0
              -ctv q4_0
              --cache-ram -1
              --reasoning off
              --temp 1.0
              --top-p 0.95
              --top-k 20
              --min-p 0.0
              --presence-penalty 0.0
              --repeat-penalty 1.0

        healthCheckTimeout: 28800  # 8 hours for large model download + loading

        # Forward llama-server (child) stdout/stderr into the llama-swap log;
        # default 'proxy' discards it, hiding load errors (e.g. CUDA OOM).
        logToStdout: both

        # TTL keeps models in memory for specified seconds after last use
        ttl: 3600  # Keep models loaded for 1 hour (like OLLAMA_KEEP_ALIVE)

        # Groups allow running multiple models simultaneously
        groups:
          autocomplete:
            # Keep next-edit model hot for blink-edit while chat models swap
            persistent: true
            swap: false
            exclusive: false
            members:
              - "sweep-next-edit:1.5b-q8"
      '';

      systemd.services.llama-swap = {
        description = "llama-swap - OpenAI compatible proxy with automatic model swapping";
        after = [ "network.target" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          Type = "simple";
          User = "goofy";
          Group = "users";
          ExecStart = "${pkgs.llama-swap}/bin/llama-swap --config /etc/llama-swap/config.yaml --listen 0.0.0.0:9292 --watch-config";
          Restart = "always";
          RestartSec = 10;
          # Environment for CUDA support
          Environment = [
            "PATH=/run/current-system/sw/bin"
            "LD_LIBRARY_PATH=/run/opengl-driver/lib:/run/opengl-driver-32/lib"
            # Single RTX 3070 Ti (GPU 0)
            "CUDA_VISIBLE_DEVICES=0"
          ];
          # Environment needs access to cache directories for model downloads
          # Simplified security settings to avoid namespace issues
          PrivateTmp = true;
          NoNewPrivileges = true;
        };
      };

    };
}
