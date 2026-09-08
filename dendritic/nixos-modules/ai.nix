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
          # Full GPU: Q5_K_M 5.24 GB + KDA+MLA KV ~0.6 GB @128K + compute 0.2 GB = ~6.1 GB
          #  → fits 8 GB RTX 3070 Ti with ~1.5 GB headroom even after desktop.
          # Official: temp=1.0, top_p=0.95, top_k=20. Source: inclusionAI/Ling-3.0-tiny-GGUF
          "ling-3.0-tiny:q5km":
            cmd: |
              ${pkgs.llama-cpp}/bin/llama-server
              -hf inclusionAI/Ling-3.0-tiny-GGUF:Q5_K_M
              --port ''${PORT}
              --jinja
              -ngl 99
              --fit off
              -c 131072
              --parallel 1
              -b 512
              -ub 256
              --flash-attn on
              -ctk q4_0
              -ctv q4_0
              --reasoning on
              --temp 1.0
              --top-p 0.95
              --top-k 20

          # K2-Horizon-3.7B Q5_K_M (512K native ctx) — agentic coding on RTX 3070 Ti.
          # Q5_K_M = 5 bpw k-quant from NANI-Nithin. Q6_K OOM'd 8GB at 64K.
          # Full GPU @64K: ~2.4 GB weights + ~2.3 GB KV q4_0 + 0.2 GB compute = ~4.9 GB ✅
          # Source: https://huggingface.co/NANI-Nithin/K2-Horizon-3.7B-GGUF
          # Official: reasoning_effort=high, temp=1.0, top_p=0.95, ≥32k output.
          "k2-horizon:3.7b-q5km":
            cmd: |
              ${pkgs.llama-cpp}/bin/llama-server
              -hf NANI-Nithin/K2-Horizon-3.7B-GGUF:K2-Horizon-3.7B-Q5_K_M
              --port ''${PORT}
              --jinja
              -ngl 99
              --fit off
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

          # K2-Horizon-7B Q4_K_M (512K native ctx) — bigger agentic model for RTX 3070 Ti.
          # Full GPU @64K: Q4_K_M ~4 GB + KV q4_0 ~2.7 GB + compute 0.2 GB = ~6.9 GB ✅
          # 128K OOMs 8GB (~4 GB weights + ~5.4 GB KV). 64K is safe max with headroom.
          # Same K2 arch as 3.7B, requires MBZUAI-IFM fork. Q4_K_M recommended general-use quant.
          # Source: https://huggingface.co/NANI-Nithin/K2-Horizon-7B-GGUF
          # Official: reasoning_effort=high, temp=1.0, top_p=0.95, ≥32k output.
          "k2-horizon:7b-q4km":
            cmd: |
              ${pkgs.llama-cpp}/bin/llama-server
              -hf NANI-Nithin/K2-Horizon-7B-GGUF:K2-Horizon-7B-Q4_K_M
              --port ''${PORT}
              --jinja
              -ngl 99
              --fit off
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
              --fit-ctx 16384
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

          # MiniCPM5-2B Q8_0 — 2.5B params, standard LlamaForCausalLM arch.
          # 128K native ctx. Has enable_thinking in chat template.
          # Mainline llama.cpp compatible (no fork needed).
          # Q8_0 ~2.5 GB fits fully on RTX 3070 Ti even at 128K ctx.
          # Source: https://huggingface.co/openbmb/MiniCPM5-2B-GGUF
          # Official: temp=1.0, top_p=0.95.
          "minicpm5-2:q8":
            cmd: |
              ${pkgs.llama-cpp}/bin/llama-server
              -hf openbmb/MiniCPM5-2B-GGUF:MiniCPM5-2B-Q8_0
              --port ''${PORT}
              --jinja
              -ngl 99
              --fit off
              -c 131072
              --parallel 1
              -b 256
              -ub 128
              --flash-attn on
              -ctk q4_0
              -ctv q4_0
              --reasoning on
              --temp 1.0
              --top-p 0.95

        healthCheckTimeout: 28800  # 8 hours for large model download + loading

        # Forward llama-server (child) stdout/stderr into the llama-swap log;
        # default 'proxy' discards it, hiding load errors (e.g. CUDA OOM).
        logToStdout: both

        # TTL keeps models in memory for specified seconds after last use
        ttl: 3600  # Keep models loaded for 1 hour (like OLLAMA_KEEP_ALIVE)
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
