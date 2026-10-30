# Memory guard for a unified-memory AMD APU: swapfile, zswap, systemd-oomd.
#
# Strix Halo has no discrete VRAM. amdgpu maps model weights into system RAM
# through GTT, so RAM pressure is GPU pressure. The 2026-10-30 hang ran at
# 100% used with SwapTotal 0. Direct reclaim found nothing to reclaim and the
# box stalled for 30 minutes.
#
# zram is the wrong tool on this hardware. Its compressed pool lives in the
# same RAM the GPU maps into, so it competes for the exhausted resource and
# adds (de)compression load to the LPDDR5x bus the weights stream over. A
# swapfile adds capacity outside RAM. zswap keeps a fast compressed path in
# front of it with a bounded pool. nixpkgs asserts zswap and zram apart for
# the same reason.
{ ... }:
{
  flake.nixosModules.strixHaloMemory =
    { config, lib, pkgs, ... }:
    {
      # The mkswap unit skips a file of the configured size, so creation runs
      # once. On btrfs it calls `btrfs filesystem mkswapfile`, which sets the
      # NoCOW flag that a swapfile needs. That branch does not create the parent
      # directory, and the unit sets DefaultDependencies=false, so the file
      # lives in /var/lib, which stage 2 already provides.
      swapDevices = [
        {
          device = "/var/lib/swapfile";
          # The tmux agent scopes peaked at 28.9 GiB on 2026-10-30.
          size = 64 * 1024; # MiB
          priority = 10;
          discardPolicy = "once";
        }
      ];

      boot.zswap = {
        enable = true;
        compressor = "zstd";
        # The pool is RAM. 5% is 6.2 GiB of 124.9 GiB. The nixpkgs default of
        # 25% would take 31 GiB away from the GPU.
        maxPoolPercent = 5;
      };

      # oomd reacts to PSI memory pressure, not to raw usage. This box idles
      # above 95% used, so a usage-based killer fires all the time.
      systemd.oomd = {
        enable = true;
        # Kill inside user slices: agent panes, containers, shells. system.slice
        # stays unmanaged so oomd never evicts the inference stack.
        enableUserSlices = true;
        settings.OOM = {
          DefaultMemoryPressureLimit = "80%";
          # A model swap presses for tens of seconds. 45 s ignores that spike.
          DefaultMemoryPressureDurationSec = 45;
        };
      };

      boot.kernel.sysctl = {
        # Evict cold anon (idle panes) before the page cache that holds the
        # mmap'd weights.
        "vm.swappiness" = 100;
        # NVMe: read one page per swap-in. Clustered reads add latency where a
        # stall-sensitive host cannot afford it.
        "vm.page-cluster" = 0;
        # Wake kswapd early. The default of 10 gives about a 128 MiB gap here.
        "vm.watermark_scale_factor" = 250;
        # 2 GiB atomic reserve. The hang left 1.8 GiB free with no reserve.
        "vm.min_free_kbytes" = 2 * 1024 * 1024;
      };

      # Keep the inference stack out of both OOM paths.
      systemd.services.llama-swap.serviceConfig = {
        OOMScoreAdjust = -700;
        ManagedOOMPreference = "avoid";
      };
      systemd.services.gufo-asr.serviceConfig = {
        OOMScoreAdjust = -700;
        ManagedOOMPreference = "avoid";
      };
    };
}
