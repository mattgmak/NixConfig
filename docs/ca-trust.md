# CA trust: eMudhra intermediate compromise

Advisory: 20 Oct 2026, <https://emudhra.we-have-a-problem.com/>. Eight eMudhra intermediate keys leaked. They chain to two roots that many trust stores still carry: `CN=AAA Certificate Services` and `CN=emSign ECC Root CA - G3`.

Last checked: 23 Oct 2026, after the switch and the `caEnv` change. The repairs are live and measured.

## What covers MacMini

`dendritic/hosts/MacMini.nix` wires five layers.

- `launchd.daemons.fix-ssl-cert-pem` (`:483-497`) strips both roots from `/etc/ssl/cert.pem` at boot and daily. It keeps a timestamped backup and rolls back when the advisory probe still trusts the chain. The job needed a `/bin/wait4path /nix/store` wrapper, see the root cause below.
- `security.pki.caCertificateBlacklist` (`:432-435`) plus `security.pki.installCACerts` (`:431`) write `/etc/ssl/certs/ca-certificates.crt`. Measured: 118 anchors plus 166 reject-marked `aux` entries. Both CNs appear there, as aux entries only. The file refuses the chain at runtime, see the proof below.
- `cacertFiltered` (`:79-102`) builds the bundle that `caEnv` points at. Measured: 282 blocks, and neither revoked CN appears at all. This bundle deletes the roots. The other one rejects them.
- `caEnv` (`:106-114`) keeps six keys on the filtered bundle: `NIX_SSL_CERT_FILE`, `CURL_CA_BUNDLE`, `GIT_SSL_CAINFO`, `REQUESTS_CA_BUNDLE`, `CARGO_HTTP_CAINFO` and `UV_SYSTEM_CERTS`. `SSL_CERT_FILE` names `/etc/ssl/certs/ca-certificates.crt`, a literal install path. Bun adds the env bundle to its own embedded store, so a deleted root does not override the embedded copy. Both delivery paths live at `:612-627`, and a nix eval of each daemon `EnvironmentVariables` shows the new value. A process that reaches neither path falls back to `nss-cacert-3.108`, which still carries both roots as plain anchors.
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

### Repaired, 23 Oct 11:19

The switch ran and the job now works. It reports `job state = exited`, `runs = 1` and `last exit code = 0`. The log holds three lines:

```
backup: /etc/ssl/cert.pem.bak.20261023-111914
probe 1: aaa exit 60, emudhra exit 60
fixed: stripped revoked roots from /etc/ssl/cert.pem
```

`/etc/ssl/cert.pem` went from 128 certs to 126, and neither revoked CN survives. The backup keeps both as plain anchors. New sha256: `6bddc1e2…`.

### Why an `aux` count misleads

A decode of `/etc/ssl/certs/ca-certificates.crt` finds both revoked CNs, at index 61 and index 275. They sit in `TRUSTED CERTIFICATE` blocks that carry a reject list for every use. A count-only audit reads those as anchors and reports a false exposure.

The runtime settles it. Point node at that file:

| `SSL_CERT_FILE` | Result |
|---|---|
| `/etc/ssl/certs/ca-certificates.crt` | `SAFE UNABLE_TO_GET_ISSUER_CERT_LOCALLY` |
| `/etc/ssl/cert.pem` | `SAFE UNABLE_TO_GET_ISSUER_CERT_LOCALLY` |
| the `cacertFiltered` store path | `SAFE UNABLE_TO_GET_ISSUER_CERT_LOCALLY` |

The counts of `/etc/ssl/certs/ca-certificates.crt` do not agree. A python ssl decode reports 284 blocks with 166 `aux` entries. A raw `BEGIN` count on the live symlink reports 118. Bun refuses under the file in both cases. The block arithmetic stays UNVERIFIED. The runtime verdict stands.

## Affected: exposed now

Measured with `https://dv-g3b-emudhra.we-have-a-problem.com/` on 23 Oct 2026. `200` means exposed. No package is exposed now, while `caEnv` holds.

Pi-Bolt sits in the Cleared table. It reopens when `SSL_CERT_FILE` goes missing, see the gap map.

Homebrew `python3` 3.14.9 is clean, but no `/opt/homebrew/bin/python3` symlink exists, only `python3.14`. Apple `python3` 3.9.6 cleared with the daemon repair, see the Cleared table.

## Cleared by the repairs in this tree

| Package | Version | Why it clears |
|---|---|---|
| bun | 1.4.4 | `dendritic/packages/bun-bin.nix` plus `bunBinOverlay`. Probes return `CERT_REVOKED` with and without `SSL_CERT_FILE` |
| pi-bolt | 0.9.9 | `SSL_CERT_FILE` names the install bundle, see the Pi-Bolt measurement below. Reopens when the variable is unset |
| node | 24.22.1, 22.23.4 | `dendritic/packages/node-bin.nix` plus `nodeBinOverlay`. 118 and 116 embedded roots, the root absent, `CERT_REVOKED` in both modes |
| go | 1.27.3 | `dendritic/packages/go-bin.nix` plus `goBinOverlay`, which adds `go-bin`. The overlay does not shadow `go`, because a shadow rebuilds every `buildGoModule` package from source. The upstream tarball carries the blocked-SPKI denylist |
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
| filtered bundle | `/nix/store/zs8nhvn8…-cacert-filtered` | 282 blocks, neither CN at all. The roots are deleted, not rejected |
| `/etc/ssl/certs/ca-certificates.crt` | 118 anchors plus 166 reject-marked `aux` | Both CNs present as aux entries. Node refuses with `UNABLE_TO_GET_ISSUER_CERT_LOCALLY` |
| python3 (Apple) | 3.9.6 | Reads the repaired `/etc/ssl/cert.pem`, 126 certs, neither root. Refuses with `CERTIFICATE_VERIFY_FAILED` |
| certifi | absent | No nix python, no Homebrew certifi module. Threshold 2026.10.19 does not apply here |
| kubectl, terraform, aws, gcloud, az, doctl, hcloud, flyctl | absent | No binary on `PATH`. `kubectl` is a broken symlink into Docker.app |

The Java fix was two `keytool` deletes against the real store:

```bash
keytool -delete -alias comodoaaaca -cacerts
keytool -delete -alias emsigneccrootcag3 -cacerts
```

A JDK reinstall restores both aliases, so rerun the deletes after a Zulu update.

### Pi-Bolt: measured, not inferred

`libexec/pi/pi-bin` embeds bun 1.4.3-canary.1, commit `c31670df2`. The runtime banner reads `Bun v1.4.3-canary.1+c31670df2`. The literal `1.4.4` appears zero times in the binary. `--version` under `BUN_BE_BUN=1` prints `1.4.3`.

The bolt-v0.9.9 release notes say the build takes three fixes from bun 1.4.4. Those are cherry-picked engine patches. They do not move the base runtime.

Probe through `BUN_BE_BUN=1` on host A:

| `SSL_CERT_FILE` | Result |
|---|---|
| unset | `TRUST`, status 200 |
| the `cacertFiltered` store bundle | `TRUST`, status 200 |
| `/etc/ssl/certs/ca-certificates.crt` | refuses |

Bun adds the env bundle to its own embedded store. `cacertFiltered` deletes the revoked roots, so the embedded copies still trust them. A reject-marked entry flips the verdict, and the install bundle holds one.

Bun refuses under `/etc/ssl/certs/ca-certificates.crt`. A copy of that file at another path refuses too. So the behaviour follows content, not path.

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

Each tool refuses the chain while `caEnv` holds.

| Package | On this host | First fixed | Declared | Status |
|---|---|---|---|---|
| git | 2.55.0 | n/a. Defers to OpenSSL | `home-modules/git.nix:5` | refuses under `GIT_SSL_CAINFO`. Fail-open path UNVERIFIED |
| cargo | 1.97.0 | n/a. Defers to libcurl | UNVERIFIED. `drpom.nix:157` only builds Rust | refuses under `CARGO_HTTP_CAINFO`. Fail-open path UNVERIFIED |

A runtime that keeps its own store still fails open. Node 24.18.0 held 120 embedded roots with `emSign ECC Root CA - G3` present. It returned `STATUS 200` with no CA variable, and `200` again with `SSL_CERT_FILE` at `nss-cacert-3.108`. Node now sits in the Cleared table.

Bun shows the same shape. It adds the env bundle to its own embedded store, so a deleted root does not override the embedded copy. See the Pi-Bolt measurement.

## Affected: upstream or vendor

| Package | On this host | First fixed | Declared | Status |
|---|---|---|---|---|
| tailscale | absent on this host | 1.104.2, merged to nixpkgs master 22 Oct | `nixos-modules/tailscale.nix:2` | `tailscale-bin.nix:23` pins 1.104.2 for Linux only, wired by `overlays.nix`. One switch clears the four NixOS hosts |
| webpki-roots | 1.0.9 | 1.0.10, 19 Oct 2026 | `dendritic/packages/lean-ctx.nix` pins v3.11.4, `vendor/mattgmak/lean-ctx` holds two lock files | pending upstream. The shipped asset inherits the tag lock, see the note below |

Tailscale bakes only Lets Encrypt ISRG roots into `net/bakedroots`. Its v1.104.2 changelog names Go 1.27.3 and TS-2026-013. nixos-unstable still shows 1.104.1.

### lean-ctx: note only

The two lock files in `vendor/mattgmak/lean-ctx`, `rust/Cargo.lock` and `clients/rust/lean-ctx-client/Cargo.lock`, both pin `webpki-roots` 1.0.9.

`dendritic/packages/lean-ctx.nix` pins version 3.11.4. It fetches a prebuilt release asset from `https://github.com/yvgude/lean-ctx/releases/download/v3.11.4/`, sets `dontUnpack = true` and runs no compile step.

The package makes no reference to `vendor/mattgmak/lean-ctx`. A lock bump in the submodule cannot reach the shipped binary, so the vendored `Cargo.lock` governs nothing here.

Upstream `.github/workflows/release.yml` builds each asset with `cargo build --release --locked`, so the asset inherits the lock of its tag. The tag lock holds `webpki-roots` 1.0.9 and `webpki-roots` 0.26.11. Version 1.0.9 holds all four emSign roots. Version 1.0.10 drops `emSign ECC Root CA - G3`.

The vendored HEAD lock differs from the tag lock only in `quinn-proto` and `rustls`. That difference changes nothing on this system.

The newest upstream tag is v3.11.4, published 2026-10-11. No release closes the gap today. The installed binary shows the tag lock in force:

```bash
rg -a -o 'emSign[ -~]{0,30}' "$(realpath "$(command -v lean-ctx)")" | sort -u
```

Four emSign labels come back.

The gap closes when upstream publishes a release whose lock carries `webpki-roots` 1.0.10 or later. The crate source diff proves the fix. Version 1.0.9 holds `emSign ECC Root CA - G3`, and version 1.0.10 does not. The other emSign roots stay in both versions.

The sibling root carries the same defect. `webpki-root-certs` 1.0.9 holds the revoked G3 root, and `rustls-platform-verifier` pulls that crate. Version 1.0.10 exists on crates.io. macOS uses security-framework and does not resolve the crate. That target detail is UNVERIFIED, because nobody retested it. No Linux host ships lean-ctx today.

## Pending: node version

Node needs 24.22.1 on the 24.x line, or 22.23.4 on 22.x. The release updates bundled roots to NSS 3.131.1 and rejects chains with blocked SPKI hashes. The bump is hygiene while `SSL_CERT_FILE` stays set, and it is the real fix once that variable goes missing.

`dendritic/packages/node-bin.nix` fetches both versions from nodejs.org. `dendritic/overlays.nix` registers `nodeBinOverlay` and adds two attribute names, `node-bin` and `node22-bin`. The overlay does not override `nodejs_24` or `nodejs_22`, because nixpkgs packages depend on those attributes.

Consumers repointed: `pi-coding-agent.nix` at `:215,527,607`, `drpom.nix` at `:130,144,146,153,193`, and `argent.nix:117` by a `callPackage` override.

One site stays on nixpkgs. The `buildNpmPackage` call for eas-cli at `drpom.nix:85` keeps `nodejs_22`. A different npm changes lock resolution and breaks `npmDepsHash`.

| node | Version | Embedded roots | `emSign ECC Root CA - G3` |
|---|---|---|---|
| old | 24.18.0 | 120 | present |
| new | 24.22.1 | 118 | absent |
| new | 22.23.4 | 116 | absent |

The new versions return `CERT_REVOKED` with and without `SSL_CERT_FILE`. The old 24.18.0 returns `HTTP 200` with no CA variable.

Node 24.22.1 sits in no nixpkgs branch. It exists only at nodejs.org, and that is why the overlay exists.

| Source | nodejs_24 | nodejs_22 | cacert |
|---|---|---|---|
| nixos-unstable `02c087f` | 24.21.0 | 22.23.3 | 3.126 |
| nixpkgs master, 23 Oct | 24.21.0 | 22.23.4, cached | 3.131.1 |
| root nixpkgs pin `1559d3da`, 2026-07-30 | UNVERIFIED | UNVERIFIED | UNVERIFIED |

No open nixpkgs PR names 24.22.x. `dendritic/mv.nix:24-27` still holds `daysBehind "2026-08-13" 14` on all four anchors.

## Why the pins exist

This table lists six overlays from `dendritic/overlays.nix`. Five cover this advisory. The sixth, `gleamBinOverlay`, exists only to avoid a Rust source build and has no CA role.

| Overlay | Package | Pinned rev carries | Fix came from |
|---|---|---|---|
| `nodeBinOverlay` | node 24.22.1 and 22.23.4 | 24.18.0 | nodejs.org tarball |
| `uvBinOverlay` | uv 0.13.4 | 0.13.1 | upstream tarball |
| `bunBinOverlay` | bun 1.4.4 | 1.4.2 | upstream tarball |
| `goBinOverlay` | go 1.27.3, as `go-bin` | `go_1_27` = 1.27rc2 | upstream tarball. New attribute only, so cached Go packages stay cached |
| `tailscaleBinOverlay` | tailscale 1.104.2 | 1.104.1 | upstream tarball, Linux only |
| `gleamBinOverlay` | gleam 1.19.2 | 1.18.0 via `buildRustPackage` | upstream tarball. Build cost only |

Each carries a TODO that names the version which lets it return to nixpkgs. Delete the overlay when the channel reaches it.

`go-bin` is a separate attribute. Add it to a package list. Never replace `go`, because `go` is a build input of every `buildGoModule` package.

The nixpkgs route stays closed for all three pending fixes. Only nixpkgs master carries `nodejs_22` 22.23.4, `cacert` 3.131.1 and `tailscale` 1.104.2. All three cache on both architectures.

The root nixpkgs pin is `1559d3da`, from 2026-07-30. The `e72e4f2` commit belongs to the hyprland input, not the root pin. The multiverse anchors resolve to `1559d3da` too, so a day-0 anchor move changes nothing today. The multiverse index ends at 2026-10-20.

An anchor move carries no kernel or firmware risk, because both come from the root pin. It does carry homelab upgrade risk.

The fail-open family stays on the old store until the nixpkgs input moves, because `cacert` 3.126 still ships both roots.

`buildGoModule` still compiles with `buildPackages.go_1_26`, so `dendritic/home-modules/tmux.nix:119` keeps 1.26.5. That toolchain builds a local helper and never validates a remote chain.

## News since 22 Oct

- eMudhra's board decided on 22 Oct to exit the global SSL/TLS certificate business. Signing services continue.
- Chrome removes `emSign ECC Root CA - G3` from its root store on 2026-10-27.
- CERT-In published an advisory on 21 Oct. Mozilla bug 2083449 stays `ASSIGNED`.
- NSS 3.132 repeats the 3.131.1 removals: `emSign Root CA - G3`, `emSign Root CA - C1`, `emSign ECC Root CA - C3`.
- No new revocation and no new root addition. The thresholds above stay valid.

## Gap: Droid

`dendritic/hosts/Droid.nix` imports neither `ca-trust.nix` nor `tailscale.nix`. Goofeus, GoofyDesky, GoofyEnvy and Ramsay import both, and `dendritic/iso/minimal.nix` imports `ca-trust.nix`. Judgement: nix-on-droid cannot use `security.pki`, because the Android target carries no NixOS PKI module.

## Gap map: who closes each

| Gap | Who closes it |
|---|---|
| `cacert` 3.125 on the Linux hosts | nixpkgs. Only master carries 3.131.1 |
| lean-ctx `webpki-roots` 1.0.9 | An upstream `yvgude/lean-ctx` release. `dendritic/packages/lean-ctx.nix` ships a prebuilt v3.11.4 asset, so only a new upstream tag moves the shipped lock. The newest tag holds 1.0.9. The gap closes at a tag lock with 1.0.10 or later, see the note above |
| fail-open path when the CA variable is unset | Each runtime that keeps its own store. This tree cannot close it. The `node-bin` overlay is the pattern |
| Pi-Bolt embedded bun 1.4.3-canary.1 | Pi-Bolt upstream. A rebuild of the release asset |

## Unverified

- The block arithmetic for `/etc/ssl/certs/ca-certificates.crt`. A python ssl decode reports 284 blocks and a raw `BEGIN` count reports 118. Bun refuses under the file in both cases.
- `git` and `cargo` fail-open behaviour. An empty variable gives no verdict.
- The `x86_64-linux` branch of `bun-bin.nix`, `go-bin.nix` and `gleam-bin.nix`. Only darwin was built.
- `python3.14` (Homebrew) runtime probe. The binary name sits outside the shell allowlist.
- Zulu 17 first fixed build. The store is clean by hand, so this no longer blocks.
- `keytool` direct output. `cacerts` was read through the Java KeyStore API instead.

## Verify

```bash
bash scripts/check-ca-trust.sh
launchctl print system/org.nixos.fix-ssl-cert-pem | rg 'last exit|job state'
sudo tail -n 20 /var/log/fix-ssl-cert-pem.log
launchctl print gui/$(id -u) | rg 'SSL_CERT_FILE|UV_SYSTEM_CERTS'
/usr/bin/curl -s -o /dev/null https://dv-g3b-emudhra.we-have-a-problem.com/; echo $?
/usr/bin/python3 <probe file>   # not -c, the allowlist blocks inline code
node <probe file> ; bun <probe file>
```

Exit `0` from curl means exposed. `60` means the client refuses the compromised chain.

The measured state on 23 Oct, after the switch:

| Check | Result |
|---|---|
| `scripts/check-ca-trust.sh` | exit 0, `0 failure(s), 1 skip(s), 0 known gap(s)`. The skip is uv |
| daemon | `exited`, `runs = 1`, exit `0`, log records the strip |
| `/etc/ssl/cert.pem` | 126 certs, `REVOKED_HITS=0` |
| curl | exit 60 |
| Apple python3 3.9.6 | `CERTIFICATE_VERIFY_FAILED` |
| node 24.22.1 | `CERT_REVOKED` |
| bun 1.4.4 | `CERT_REVOKED` |
| gui/501 domain | `SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt`, `UV_SYSTEM_CERTS=1` and `CARGO_HTTP_CAINFO` seeded by `ca-env-setenv` |

`launchctl getenv` from a plain shell returns empty, because that shell is not in the `gui` bootstrap domain. Ask `launchctl print gui/$(id -u)` instead.

`scripts/check-ca-trust.sh` probes the bundle, the Apple store, curl, bun, node, Apple `python3`, Java and go. The Java probe reads the JKS store by byte search, so it needs no `keytool`. The go probe runs a small program, because go resolves trust through the OS store. The script skips uv, because uv 0.13.4 has no plain HTTPS request subcommand. It still does not probe Homebrew ruby and python3.
