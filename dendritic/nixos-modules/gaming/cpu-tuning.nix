{
  flake.nixosModules.cpuTuning =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.services.cpuTuning;

      cpuStatus = pkgs.writeShellScriptBin "cpu-status" ''
        set -euo pipefail

        echo "=== CPU model ==="
        grep -m1 'model name' /proc/cpuinfo

        echo
        echo "=== Governor / frequencies ==="
        if command -v cpupower >/dev/null 2>&1; then
          cpupower frequency-info 2>/dev/null | sed -n '1,12p' || true
        fi
        for cpu in /sys/devices/system/cpu/cpu[0-9]*; do
          [ "$(basename "$cpu")" = "cpu0" ] || continue
          echo "cpu0: $(cat "$cpu/cpufreq/scaling_governor" 2>/dev/null) \
$(cat "$cpu/cpufreq/scaling_cur_freq" 2>/dev/null) kHz cur / \
$(cat "$cpu/cpufreq/scaling_max_freq" 2>/dev/null) kHz max"
        done

        echo
        echo "=== Temperatures ==="
        if command -v sensors >/dev/null 2>&1; then
          sensors 2>/dev/null || echo "(sensors: run 'sudo sensors-detect' once if empty)"
        else
          echo "sensors not installed"
        fi

        echo
        echo "=== Package power / temp (needs root) ==="
        if [ "$(id -u)" -eq 0 ]; then
          ${pkgs.linuxPackages.turbostat}/bin/turbostat --Summary --quiet \
            --show PkgTmp,PkgWatt -n 1 2>/dev/null || true
        else
          echo "run: sudo cpu-status"
        fi
      '';

      cpuStress = pkgs.writeShellScriptBin "cpu-stress" ''
        set -euo pipefail

        DURATION="''${1:-60}"
        WORKERS="''${2:-8}"

        echo "Stress ''${WORKERS} workers for ''${DURATION}s. Watch temps: watch -n1 sensors"
        echo "Ctrl+C to stop early."
        echo

        ${pkgs.stress-ng}/bin/stress-ng \
          --cpu "$WORKERS" \
          --cpu-method all \
          --timeout "$DURATION" \
          --metrics-brief
      '';

      cpuBench = pkgs.writeShellScriptBin "cpu-bench" ''
        set -euo pipefail

        echo "=== Baseline before BIOS tuning changes ==="
        echo "Record this output, then compare after tuning."
        echo

        cpu-status

        echo
        echo "=== 30s all-core stress (8 workers) ==="
        cpu-stress 30 8
      '';
    in
    {
      options.services.cpuTuning = {
        enable = lib.mkEnableOption "CPU verification tools and monitoring scripts";

        governor = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = "schedutil";
          description = "cpufreq governor. null = leave kernel default. Use performance for OC validation.";
        };
      };

      config = lib.mkIf cfg.enable {
        hardware.cpu.x86.msr.enable = true;

        boot.kernelModules = [
          "msr"
          "intel_rapl"
        ];

        powerManagement.cpuFreqGovernor = lib.mkIf (cfg.governor != null) cfg.governor;

        environment.systemPackages = with pkgs; [
          stress-ng
          lm_sensors
          hwinfo
          linuxPackages.cpupower
          linuxPackages.turbostat
          cpuStatus
          cpuStress
          cpuBench
        ];
      };
    };
}
