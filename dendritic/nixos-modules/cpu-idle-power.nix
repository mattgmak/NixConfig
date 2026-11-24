# Idle power for a Strix Halo APU on amd-pstate-epp.
#
# The driver exposes two governors only, powersave and performance. It has no
# schedutil, so NixOS powerManagement.cpuFreqGovernor must not name one.
#
# Two defaults keep 32 idle cores high. scaling_min_freq reads 2000000 against
# a cpuinfo_min_freq of 625000, because epp mode floors it at the CPPC
# lowest-nonlinear point. EPP starts at balance_performance. On 2026-10-23 the
# package drew 12-13 W at 3% busy with every core between 1.8 and 3.6 GHz.
#
# A driver clamp can win over the min limit, so verify after the switch:
#   cpupower frequency-info | grep -e limits -e current
#   cat /sys/devices/system/cpu/cpu0/cpufreq/energy_performance_preference
{ ... }:
{
  flake.nixosModules.cpuIdlePower =
    { lib, ... }:
    {
      # cpupower frequency-set --min. This also pulls in cpupower and the
      # cpufreq.service unit, which runs after systemd-modules-load.
      powerManagement.cpufreq.min = lib.mkDefault 625000;

      # NixOS holds no option for EPP, so one unit writes it per policy.
      # cpufreq.service sets the governor and the limits first. balance_power
      # keeps idle saving and a fast ramp, where power slows a long build.
      systemd.services.cpu-epp = {
        description = "Set CPU energy performance preference to balance_power";
        after = [ "cpufreq.service" ];
        wants = [ "cpufreq.service" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        script = ''
          for f in /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference; do
            echo balance_power > "$f" || echo "cpu-epp: $f rejected"
          done
        '';
      };
    };
}
