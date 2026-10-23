# CA trust: eMudhra intermediate compromise

Advisory: 20 Oct 2026, <https://emudhra.we-have-a-problem.com/>. Eight eMudhra intermediate keys leaked. They chain to two roots that many trust stores still carry: `CN=AAA Certificate Services` and `CN=emSign ECC Root CA - G3`.

Last checked: 23 Oct 2026. Four repairs sit in the tree and wait for one `nh switch`.

## What covers MacMini

`dendritic/hosts/MacMini.nix` wires five layers.

- `launchd.daemons.fix-ssl-cert-pem` (`:483-497`) strips both roots from `/etc/ssl/cert.pem` at boot and daily. It keeps a timestamped backup and rolls back when the advisory probe still trusts the chain. The job needed a `/bin/wait4path /nix/store` wrapper, see the root cause below.
- `security.pki.caCertificateBlacklist` (`:432-435`) plus `security.pki.installCACerts` (`:431`) write `/etc/ssl/certs/ca-certificates.crt`. Measured: 118 certs, neither CN, no `aux` entries.
- `cacertFiltered` (`:79-102`) builds the bundle that `caEnv` points at. Measured: 118 certs, neither revoked CN, no `aux` entries.
- `caEnv` (`:106-114`) names the filtered bundle for seven variables: `SSL_CERT_FILE`, `NIX_SSL_CERT_FILE`, `CURL_CA_BUNDLE`, `GIT_SSL_CAINFO`, `REQUESTS_CA_BUNDLE`, `CARGO_HTTP_CAINFO` and `UV_SYSTEM_CERTS`. Both delivery paths live at `:612-627`. A process that reaches neither path falls back to `nss-cacert-3.108`, which still carries both roots as plain anchors.
- An overlay for `python3Packages.certifi` would repoint its `cacert.pem` symlink from the unfiltered `pkgs.cacert` to `cacertFiltered`. nixpkgs certifi carries no store of its own: it links `cacert.pem` at `${cacert}/etc/ssl/certs/ca-bundle.crt`. No nix python exists on this host.

## Root cause found: /nix mounts late

`launchd` runs a `RunAtLoad` daemon as soon as the system domain starts. `/nix` is a separate APFS volume, and `/etc/fstab` marks it `noauto`. `systems.determinate.nix-store` unlocks and mounts it after boot. So a program path under `/nix/store` does not resolve at spawn time. The spawn then fails with 78 `EX_CONFIG` and an empty log.

Evidence from 23 Oct:

- `launchctl print system/org.nixos.fix-ssl-cert-pem` reports `runs = 1`, `last exit code = 78: EX_CONFIG`, `job state = spawn failed`.
- `/var/log/fix-ssl-cert-pem.log` was 0 bytes, so no shell ever started.
- `/etc/ssl/cert.pem` held 128 certs with both revoked roots as plain anchors, and the backup was byte-identical to it.
- The sibling job `org.nixos.activate-system` wraps its program in `/bin/wait4path /nix/store` and exits 0. `org.nixos.nix-gc` had the same defect and the same 78.

Both daemons now use the wrapper:

```nix
ProgramArguments = [
  "/bin/sh"
  "-c"
  "/bin/wait4path /nix/store && exec <program>"
];
```

`launchd.user.agents.nix-gc` (`:465`) stays unwrapped. It runs at login, after the mount.

You need a switch before the file gets patched. `launchctl kickstart` alone masks the boot defect and proves nothing.

## Affected: exposed now

Measured with `https://dv-g3b-emudhra.we-have-a-problem.com/` on 23 Oct 2026. `200` means exposed.

| Package | On this host | First fixed | Declared | Status |
|---|---|---|---|---|
| python3 (Apple) | 3.9.6 | n/a. Reads the Apple store | `/usr/bin/python3`, the `python3` on `PATH` | exposed. `/etc/ssl/cert.pem` holds both roots until the repaired daemon runs |
| pi-bolt | 0.9.9 | follows its bundled bun | `dendritic/packages/pi-bolt.nix:15,41` | AOT bun binary from a prebuilt release asset. The `pkgs.bun` overlay cannot touch it. Bundled bun version UNVERIFIED |

Homebrew `python3` 3.14.9 is clean, but no `/opt/homebrew/bin/python3` symlink exists, only `python3.14`.

## Cleared by the repairs in this tree

| Package | Version | Why it clears |
|---|---|---|
| bun | 1.4.4 | `dendritic/packages/bun-bin.nix` plus `bunBinOverlay`. Probes return `CERT_REVOKED` with and without `SSL_CERT_FILE` |
| go | 1.27.3 | `dendritic/packages/go-bin.nix` plus `goBinOverlay`. The upstream tarball carries the blocked-SPKI denylist |
| uv | 0.13.4 | `dendritic/packages/uv-bin.nix:19`. Probes refuse with `UnknownIssuer` |
| ruby (Homebrew) | 4.0.7_1 | Loads 188 CAs from the clean `openssl@4` keg. Refuses with the env deleted |
| gem (Homebrew) | 4.0.20 | Same clean keg |
| python3 (Homebrew) | 3.14.9 | Same clean keg. Not on `PATH` as `python3` |
| ruby (nix) | 3.4.9 | Reads the clean nix `ca-certificates`. Refuses with the env deleted |
| python3 (nix, via uv) | 3.13.16 | Reads the filtered bundle, 164 loaded. Refuses with code 20 |
| java (Zulu 17) | 17.0.20 | Both aliases deleted from the real `cacerts`. 109 entries remain. Probes fail PKIX while TLS still completes |
| curl (system) | 8.7.1 SecureTransport | Refuses with exit 60 through SecureTransport |
| rustc | 1.97.0 | Offline compiler, no store |
| openssl | 3.6.3 | No store of its own. Follows the filtered bundle |
| filtered bundle | `/nix/store/zs8nhvn8…-cacert-filtered` | 118 certs, neither CN, no `aux` entries |
| `/etc/ssl/certs/ca-certificates.crt` | 118 certs | Neither CN. Decoded 23 Oct |
| certifi | absent | No nix python, no Homebrew certifi module. Threshold 2026.10.19 does not apply here |
| kubectl, terraform, aws, gcloud, az, doctl, hcloud, flyctl | absent | No binary on `PATH`. `kubectl` is a broken symlink into Docker.app |

The Java fix was two `keytool` deletes against the real store:

```bash
keytool -delete -alias comodoaaaca -cacerts
keytool -delete -alias emsigneccrootcag3 -cacerts
```

A JDK reinstall restores both aliases, so rerun the deletes after a Zulu update.

### The keychain already rejects the chain

The Apple keychain does not trust either root. Measured with the upstream direnv 2.37.1 release binary. That binary uses Go's darwin platform verifier and holds no store of its own.

```bash
direnv fetchurl https://dv-g3b-emudhra.we-have-a-problem.com/ sha256-AAAA…=
# direnv: error Get "https://dv-g3b-emudhra.we-have-a-problem.com/": tls: failed to verify
#   certificate: x509: “EM DV TLS CA - G3B” certificate is revoked
```

The same refusal appears with `SSL_CERT_FILE` at the filtered bundle and with `SSL_CERT_FILE` at the dirty `/etc/ssl/cert.pem`. The binary reports `go1.24.4`, so the verdict comes from the platform verifier and not from Go's 1.27.3 denylist. System curl refuses with exit 60 for the same reason.

So the dirty `/etc/ssl/cert.pem` exposes only the clients that read it as a file. OpenSSL clients do, and Apple `python3` is one of them. SecureTransport and Go clients ask the keychain instead, and `SSL_CERT_FILE` does not reach them on darwin.

## Affected: fails open when the env is missing

Each tool refuses the chain while the filtered bundle sits in the environment.

| Package | On this host | First fixed | Declared | Status |
|---|---|---|---|---|
| node | 24.18.0 | 24.22.1 on 24.x, 22.23.4 on 22.x | `pi-coding-agent.nix:215,527,607`, `drpom.nix:76`, `argent.nix:15` | refuses with the env. Accepts host A without it. Compiled roots are 120 and hold `emSign ECC Root CA - G3` |
| git | 2.55.0 | n/a. Defers to OpenSSL | `home-modules/git.nix:5` | refuses under `GIT_SSL_CAINFO`. Fail-open path UNVERIFIED |
| cargo | 1.97.0 | n/a. Defers to libcurl | UNVERIFIED. `drpom.nix:157` only builds Rust | refuses under `CARGO_HTTP_CAINFO`. Fail-open path UNVERIFIED |

Node is the sharpest case. A deleted or empty variable gives `STATUS 200`, so the guard is the variable itself, not the binary. `SSL_CERT_FILE` pointing at `nss-cacert-3.108` gives `200` too.

## Affected: upstream or vendor

| Package | On this host | First fixed | Declared | Status |
|---|---|---|---|---|
| tailscale | absent on this host | 1.104.2, merged to nixpkgs master 22 Oct | `nixos-modules/tailscale.nix:2` | `tailscale-bin.nix:23` pins 1.104.2 for Linux only, wired by `overlays.nix`. One switch clears the four NixOS hosts |
| webpki-roots | 1.0.9 | 1.0.10, 19 Oct 2026 | `vendor/mattgmak/lean-ctx`, two lock files | pending upstream. See the note below |

Tailscale bakes only Lets Encrypt ISRG roots into `net/bakedroots`. Its v1.104.2 changelog names Go 1.27.3 and TS-2026-013. nixos-unstable still shows 1.104.1.

### lean-ctx: note only

Upstream `yvgude/lean-ctx` still pins `webpki-roots` 1.0.9 in `rust/Cargo.lock` and `clients/rust/lean-ctx-client/Cargo.lock`. Version 1.0.9 holds all four emSign roots. Version 1.0.10 drops `emSign ECC Root CA - G3`.

We own `mattgmak/lean-ctx`, so a fork patch is possible. It would not help. `dendritic/packages/lean-ctx.nix` fetches the `v3.11.4` release tarball, and that tarball embeds the 1.0.9 roots. The installed binary proves it:

```bash
rg -a -o 'emSign[ -~]{0,30}' "$(realpath "$(command -v lean-ctx)")" | sort -u
```

Four emSign labels come back. So the fix arrives with an upstream release built from a bumped engine lock, or not at all.

## Pending: node version

Node needs 24.22.1 on the 24.x line, or 22.23.4 on 22.x. The release updates bundled roots to NSS 3.131.1 and rejects chains with blocked SPKI hashes. The bump is hygiene while `SSL_CERT_FILE` stays set, and it is the real fix once that variable goes missing.

No nixpkgs branch carries 24.22.1 yet. A 22.x bump reached master on 21 Oct.

| Source | nodejs_24 | nodejs_22 | cacert |
|---|---|---|---|
| nixos-unstable `02c087f` | 24.21.0 | 22.23.3 | 3.126 |
| nixpkgs master, 23 Oct | 24.21.0 | 22.23.4, cached | 3.131.1 |
| root nixpkgs pin `e72e4f2` | 24.21.0 | — | — |

No open nixpkgs PR names 24.22.x. `dendritic/mv.nix:24-27` still holds `daysBehind "2026-08-13" 14` on all four anchors. The fail-open family also stays on the old store until the nixpkgs input moves, because `cacert` 3.126 still ships both roots.

## Why the pins exist

Four overlays in `dendritic/overlays.nix` cover one gap: the pinned nixpkgs rev cannot supply a fixed version.

| Overlay | Package | Pinned rev carries | Fix came from |
|---|---|---|---|
| `uvBinOverlay` | uv 0.13.4 | 0.13.1 | upstream tarball |
| `bunBinOverlay` | bun 1.4.4 | 1.4.2 | upstream tarball |
| `goBinOverlay` | go 1.27.3 | `go_1_27` = 1.27rc2 | upstream tarball |
| `tailscaleBinOverlay` | tailscale 1.104.2 | 1.104.1 | upstream tarball, Linux only |

Each carries a TODO that names the version which lets it return to nixpkgs. Delete the overlay when the channel reaches it.

`buildGoModule` still compiles with `buildPackages.go_1_26`, so `dendritic/home-modules/tmux.nix:119` keeps 1.26.5. That toolchain builds a local helper and never validates a remote chain.

## News since 22 Oct

- eMudhra's board decided on 22 Oct to exit the global SSL/TLS certificate business. Signing services continue.
- Chrome removes `emSign ECC Root CA - G3` from its root store on 2026-10-27.
- CERT-In published an advisory on 21 Oct. Mozilla bug 2083449 stays `ASSIGNED`.
- NSS 3.132 repeats the 3.131.1 removals: `emSign Root CA - G3`, `emSign Root CA - C1`, `emSign ECC Root CA - C3`.
- No new revocation and no new root addition. The thresholds above stay valid.

## Gap: Droid

`dendritic/hosts/Droid.nix` imports neither `ca-trust.nix` nor `tailscale.nix`. Goofeus, GoofyDesky, GoofyEnvy and Ramsay import both, and `dendritic/iso/minimal.nix` imports `ca-trust.nix`. Judgement: nix-on-droid cannot use `security.pki`, because the Android target carries no NixOS PKI module.

## Unverified

- The bun version inside the pi-bolt 0.9.9 release asset.
- Go and the Apple keychain. The `security` command stays blocked.
- `git` and `cargo` fail-open behaviour. An empty variable gives no verdict.
- The `x86_64-linux` branch of `bun-bin.nix` and `go-bin.nix`. Only darwin was built.
- `python3.14` (Homebrew) runtime probe. The binary name sits outside the shell allowlist.
- Zulu 17 first fixed build. The store is clean by hand, so this no longer blocks.
- `keytool` direct output. `cacerts` was read through the Java KeyStore API instead.

## Verify

```bash
bash scripts/check-ca-trust.sh
launchctl print system/org.nixos.fix-ssl-cert-pem | rg 'last exit|job state'
sudo tail -n 20 /var/log/fix-ssl-cert-pem.log
launchctl getenv SSL_CERT_FILE
/usr/bin/curl -s -o /dev/null https://dv-g3b-emudhra.we-have-a-problem.com/; echo $?
node -e "require('https').get('https://dv-g3b-emudhra.we-have-a-problem.com/',()=>console.log('exposed')).on('error',e=>console.log('safe',e.code))"
bun -e "fetch('https://dv-g3b-emudhra.we-have-a-problem.com/').then(r=>console.log('exposed',r.status)).catch(e=>console.log('safe',e.code||e.message))"
```

Exit `0` from curl means exposed. `60` means the client refuses the compromised chain. After the switch, the daemon log must show `probe 1: aaa exit 60, emudhra exit 60`.

`scripts/check-ca-trust.sh` probes the bundle, the Apple store, curl and bun. It does not probe node, uv, Java, go, or Homebrew ruby and python3.
