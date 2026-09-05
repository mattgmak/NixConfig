{
  flake.nixosModules.gpuTuning =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.services.gpuTuning;
      nvidiaSmi = "${lib.getBin config.hardware.nvidia.package}/bin/nvidia-smi";

      gpuStatus = pkgs.writeShellScriptBin "gpu-status" ''
        set -uo pipefail

        echo "=== GPU summary ==="
        ${nvidiaSmi} --query-gpu=index,name,driver_version,pstate,temperature.gpu,utilization.gpu,power.draw,power.limit,clocks.current.graphics,clocks.current.memory,clocks.max.graphics,clocks.max.memory --format=csv

        echo
        echo "=== Power limit range ==="
        ${nvidiaSmi} --query-gpu=power.min_limit,power.max_limit,power.default_limit --format=csv

        echo
        echo "=== Supported clocks (top of ladder) ==="
        ${nvidiaSmi} -q -d SUPPORTED_CLOCKS 2>/dev/null | sed -n '1,25p' || true
      '';

      gpuLock = pkgs.writeShellScriptBin "gpu-lock" ''
        set -euo pipefail

        if [ "$(id -u)" -ne 0 ]; then
          echo "run: sudo gpu-lock <graphics_mhz> [mem_mhz]"
          exit 1
        fi

        GFX="''${1:?graphics mhz required, e.g. 1905}"
        MEM="''${2:-}"

        ${nvidiaSmi} -pm 1
        ${nvidiaSmi} -i 0 -lgc "$GFX,$GFX"
        echo "locked graphics: ''${GFX} MHz"

        if [ -n "$MEM" ]; then
          ${nvidiaSmi} -i 0 -lmc "$MEM,$MEM"
          echo "locked memory: ''${MEM} MHz"
        fi
      '';

      gpuReset = pkgs.writeShellScriptBin "gpu-reset" ''
        set -euo pipefail

        if [ "$(id -u)" -ne 0 ]; then
          echo "run: sudo gpu-reset"
          exit 1
        fi

        ${nvidiaSmi} -i 0 -rgc 2>/dev/null || true
        ${nvidiaSmi} -i 0 -rmc 2>/dev/null || true
        ${nvidiaSmi} -i 0 -pl 310000 2>/dev/null || true
        echo "reset locked clocks + power limit to 310 W"
      '';

      gpuPower = pkgs.writeShellScriptBin "gpu-power" ''
        set -euo pipefail

        if [ "$(id -u)" -ne 0 ]; then
          echo "run: sudo gpu-power <watts>"
          exit 1
        fi

        WATTS="''${1:?watts required, e.g. 280}"
        # NOTE: driver 595.84 nvidia-smi -pl takes WATTS, not milliwatts.
        # The earlier MW=$((WATTS*1000)) was wrong — passed 280000 W, rejected.
        ${nvidiaSmi} -i 0 -pl "$WATTS"
        echo "power limit: ''${WATTS} W"
      '';

      gpuWatch = pkgs.writeShellScriptBin "gpu-watch" ''
        set -euo pipefail
        echo "Ctrl+C to stop. columns: power temp gfxclk memclk util"
        ${nvidiaSmi} dmon -s pucmt -d 1
      '';

      gpuBench = pkgs.writeShellScriptBin "gpu-bench" ''
        set -euo pipefail

        echo "=== GPU baseline before tuning ==="
        echo "Record this output, then compare after changes."
        echo

        gpu-status

        echo
        echo "=== 30s GPU load (vulkan cube) ==="
        echo "Watch in another terminal: nvidia-smi dmon -s pucmt -d 1"
        echo

        if command -v vkcube >/dev/null 2>&1; then
          timeout 30 vkcube 2>/dev/null || true
        else
          echo "vkcube not installed — use a game or: nvidia-smi dmon -s pucmt -d 1"
        fi

        echo
        gpu-status
      '';
    in
    {
      options.services.gpuTuning = {
        enable = lib.mkEnableOption "GPU tuning tools and verification scripts";

        powerLimit = lib.mkOption {
          type = lib.types.nullOr lib.types.int;
          default = null;
          description = "Apply power limit in watts on boot. null = don't override stock.";
        };

        lockGraphicsMhz = lib.mkOption {
          type = lib.types.nullOr lib.types.int;
          default = null;
          description = "Lock graphics clock (min=max) on boot. null = stock boost. Linux UV proxy.";
        };

        lockMemoryMhz = lib.mkOption {
          type = lib.types.nullOr lib.types.int;
          default = null;
          description = "Lock memory clock on boot. null = stock. GDDR6X: start small (+0) until stable.";
        };
      };

      config = lib.mkIf cfg.enable {
        environment.systemPackages = with pkgs; [
          nvidia_oc
          vulkan-tools
          gpuStatus
          gpuLock
          gpuReset
          gpuPower
          gpuWatch
          gpuBench
        ];

        systemd.services.gpu-tuning = lib.mkIf (
          cfg.lockGraphicsMhz != null || cfg.powerLimit != null
        ) {
          description = "Apply GPU clock/power profile";
          wantedBy = [ "multi-user.target" ];
          after = [ "nvidia-persistenced.service" ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            ExecStart = pkgs.writeShellScript "gpu-tuning-apply" ''
              set -euo pipefail
              ${nvidiaSmi} -pm 1
              ${lib.optionalString (cfg.powerLimit != null) ''
                # -pl takes watts on driver 595.84 (no * 1000 — that passed 341000 W, rejected)
                ${nvidiaSmi} -i 0 -pl ${toString cfg.powerLimit}
              ''}
              ${lib.optionalString (cfg.lockGraphicsMhz != null) ''
                ${nvidiaSmi} -i 0 -lgc ${toString cfg.lockGraphicsMhz},${toString cfg.lockGraphicsMhz}
              ''}
              ${lib.optionalString (cfg.lockMemoryMhz != null) ''
                ${nvidiaSmi} -i 0 -lmc ${toString cfg.lockMemoryMhz},${toString cfg.lockMemoryMhz}
              ''}
            '';
          };
        };
      };
    };
}
