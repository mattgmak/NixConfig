let
  builderSites = {
    goofydesky = {
      hostName = "goofydesky.dab-octatonic.ts.net";
      sshUser = "goofy";
      publicKey = "goofydesky.dab-octatonic.ts.net:B+pUQuLwq9wN7AetOiViDXT1q89szpTxU4kSSZwb1EE=";
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      maxJobs = 16;
      speedFactor = 1;
      supportedFeatures = [
        "benchmark"
        "big-parallel"
        "kvm"
        "nixos-test"
      ];
      secretFile = "nix-builder-goofydesky.age";
    };
    goofeus = {
      hostName = "goofeus.dab-octatonic.ts.net";
      sshUser = "root";
      publicKey = "goofeus.dab-octatonic.ts.net:ZsXB0M4jMo4KhUQwLw9UoT6YcmKXuEiv6nMczc5jM+I=";
      systems = [ "x86_64-linux" ];
      maxJobs = 8;
      speedFactor = 1;
      supportedFeatures = [
        "benchmark"
        "big-parallel"
        "kvm"
        "nixos-test"
      ];
      secretFile = "nix-builder-goofeus.age";
    };
  };
in
{
  flake.constants = {
    username = "goofy";
    laptopName = "GoofyEnvy";
    wslName = "GoofyWSL";
    vmName = "GoofyVM";
    macMiniName = "MacMini";
    desktopName = "GoofyDesky";
    serverName = "Goofeus";
  };

  flake.builderSites = builderSites;
  flake.builderPublicKeys = builtins.map (site: site.publicKey) (builtins.attrValues builderSites);
}
