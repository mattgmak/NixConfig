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

          # Latest Unsloth Qwen3.6-27B dense MTP model, verified 2026-05-17.
          # RTX 3070 Ti (8 GB): UD-Q4_K_XL + CPU offload; MTP disabled (needs extra VRAM).
          # Source: https://huggingface.co/unsloth/Qwen3.6-27B-MTP-GGUF
          "qwen3.6:27b-q4":
            cmd: |
              ${pkgs.llama-cpp}/bin/llama-server
              -hf unsloth/Qwen3.6-27B-MTP-GGUF:UD-Q4_K_XL
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

        healthCheckTimeout: 28800  # 8 hours for large model download + loading

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
