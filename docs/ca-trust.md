# CA trust: eMudhra intermediate compromise

Advisory of 20 Oct 2026: eight leaked intermediate keys chain to `CN=AAA Certificate Services` and `CN=emSign ECC Root CA - G3`. Every remediation in this tree landed and passed its check on 6 Nov 2026. The full record lives in git at commit `eaa88f6`.

## Open items

1. Switch Ramsay with `nh` to deploy the `bunBin` and `lean-ctx` binaries.
1. Switch Goofeus, GoofyDesky, and GoofyEnvy to the same nixpkgs pin.
1. Run the two `keytool` deletes on MacMini (`comodoaaaca`, `emsigneccrootcag3`) against the Zulu 17 `cacerts`. A JDK reinstall restores both aliases and forces a rerun.
1. Run `scripts/check-ca-trust.sh` on macOS. The python3 and ruby probes report `SKIP` on Linux.
1. Confirm `go_1_27` reaches the system closure after the switch. `dendritic/common.nix:280` lists it, and no go path sits in the closure now.
1. Drop `dendritic/packages/bun-bin.nix` when nixpkgs ships bun 1.4.4. nixpkgs is at 1.4.2.
