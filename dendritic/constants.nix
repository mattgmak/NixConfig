let
  builderSites = {
    goofydesky = {
      hostName = "goofydesky.dab-octatonic.ts.net";
      sshUser = "goofy";
      nixPublicKey = "goofydesky.dab-octatonic.ts.net:B+pUQuLwq9wN7AetOiViDXT1q89szpTxU4kSSZwb1EE=";
      sshPublicKey = "AAAAC3NzaC1lZDI1NTE5AAAAIMq/zGCOmrHUwNRwjDsj8Sw0PDbnMd3Ck7H/ZKsHKPkM";
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
      nixPublicKey = "goofeus.dab-octatonic.ts.net:ZsXB0M4jMo4KhUwLw9UoT6YcmKXuEiv6nMczc5jM+I=";
      sshPublicKey = "AAAAC3NzaC1lZDI1NTE5AAAAIJeW872aIf7gEz8mS6MOLOaheMNpJghqVppQlUYSqq4x";
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
    # speedFactor above 1 makes x86_64 clients offload here. A factor of 1 never
    # beats the local implicit factor of 1, so the older two entries never offload.
    ramsay = {
      hostName = "ramsay.dab-octatonic.ts.net";
      sshUser = "root";
      nixPublicKey = "ramsay.dab-octatonic.ts.net:PDwAu1/TAp46ziQMg3Wrhh+c2wa58OQzW+T/XG9dY9M=";
      sshPublicKey = "AAAAC3NzaC1lZDI1NTE5AAAAII1zk63+hPq2dUA/6MUgLW3ryisp/dZQ8GuiPDYpyiFK";
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      maxJobs = 10;
      speedFactor = 4;
      supportedFeatures = [
        "benchmark"
        "big-parallel"
        "kvm"
        "nixos-test"
      ];
      secretFile = "nix-builder-ramsay.age";
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
    ramsayName = "Ramsay";
  };

  flake.builderSites = builderSites;
  flake.builderPublicKeys =
    builtins.map (site: site.nixPublicKey) (builtins.attrValues builderSites);

  # One builderSites entry to one nix.buildMachines entry. buildMachines checks
  # the SSH host key; nix checks the signing key through trusted-public-keys.
  flake.mkBuilder =
    site: extra:
    {
      inherit (site) hostName sshUser systems maxJobs speedFactor supportedFeatures;
      protocol = "ssh-ng";
      publicHostKey = site.sshPublicKey;
    }
    // extra;
}
