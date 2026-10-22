# CA trust: eMudhra intermediate compromise

Advisory: 20 Oct 2026, <https://emudhra.we-have-a-problem.com/>. Eight eMudhra intermediate keys leaked. They chain to two roots that many trust stores still carry: `CN=AAA Certificate Services` and `CN=emSign ECC Root CA - G3`.

## What covers MacMini

`dendritic/hosts/MacMini.nix` wires five layers.

- `launchd.daemons.fix-ssl-cert-pem` strips both roots from `/etc/ssl/cert.pem` at boot and daily. It keeps a timestamped backup and rolls back when the advisory probe still trusts the chain. A daemon is needed because Apple updates replace that file, and no macOS release shipped a clean copy.
- `security.pki.caCertificateBlacklist` writes `/etc/ssl/certs/ca-certificates.crt`. That file still holds the reject-marked `aux` DER for both roots, with an empty trust set. A name grep reads this as a hit and gives a false positive.
- `cacertFiltered` (`:79-102`) builds the bundle that `caEnv` points at. It keeps 118 certs and holds neither revoked CN.
- `caEnv` (`:106-114`) names the filtered bundle for seven variables: `SSL_CERT_FILE`, `NIX_SSL_CERT_FILE`, `CURL_CA_BUNDLE`, `GIT_SSL_CAINFO`, `REQUESTS_CA_BUNDLE`, `CARGO_HTTP_CAINFO` and `UV_SYSTEM_CERTS`. Both delivery paths live at `:612-624`. `environment.variables` writes them into `/etc/static/zshenv`, which zsh sources on every run. `launchd.user.agents.ca-env-setenv` seeds the launchd user domain once per login. A process that reaches neither path sees none of them, and falls back to `nss-cacert-3.108`. That bundle still carries both roots as plain trust anchors, which gives the fail-open path below.
- An overlay for `python3Packages.certifi` would repoint its `cacert.pem` symlink from the unfiltered `pkgs.cacert` to `cacertFiltered`. nixpkgs certifi carries no store of its own: it links `cacert.pem` at `${cacert}/etc/ssl/certs/ca-bundle.crt`. No nix python exists on this host. Add the overlay when a python environment needs it.

`security.pki.installCACerts` (`:420`) and the `fix-ssl-cert-pem` job (`:428-438`) stay as they are. The `caEnv` vars reach a login shell only, so a login shell refuses the chain for every tool that honors them.

## Environment delivery

Checked on 22 Oct 2026, before the pending switch.

- `launchctl getenv SSL_CERT_FILE` returns empty. The launchd user domain holds no `caEnv` value.
- `/etc/static/zshenv` sources a generated file that exports four of the seven `caEnv` variables: `SSL_CERT_FILE`, `NIX_SSL_CERT_FILE`, `CURL_CA_BUNDLE` and `GIT_SSL_CAINFO`. The live generation predates `REQUESTS_CA_BUNDLE`, `CARGO_HTTP_CAINFO` and `UV_SYSTEM_CERTS`.
- `/Library/LaunchAgents/org.nixos.ca-env-setenv.plist` is absent. The service is not loaded.

One `nh` switch plus a logout closes both gaps. Verify with:

```bash
launchctl getenv SSL_CERT_FILE
ls /Library/LaunchAgents/org.nixos.ca-env-setenv.plist
```

## Affected: uv clears with the pending env switch

Measured with `https://dv-g3b-emudhra.we-have-a-problem.com/` on 22 Oct 2026. `200` means exposed. The uv row needs the `nh switch` that lands `caEnv`. The bun row needs a release.

| Package | On this host | First fixed | Declared | Status |
|---|---|---|---|---|
| bun | 1.3.13 | no release. main `ea6a2c7` only | `pi-coding-agent.nix:217,529,611` | exposed. No environment variable stops it. The release is the only fix |
| uv | 0.12.0 | 0.13.4, 20 Oct 2026 | `MacMini.nix:595`, `pi-coding-agent.nix:610` | exposed. `UV_SYSTEM_CERTS=1` ships at `:113` and clears it after one switch |

The Homebrew keg at `/opt/homebrew/etc/ca-certificates/cert.pem` held 191 certs and both roots as plain anchors before the upgrade. `brew upgrade ca-certificates` moved it 2026-08-13 to 2026-10-20 and cut it to 188 certs, with both CNs absent by decode. Ruby, gem, python3 and the `openssl@4` CAfile now read the clean keg. The versions before the upgrade trusted the chain: ruby 4.0.6, gem 4.0.16, python3 3.14.7.

The delivery gap now has a repo-side fix. `caEnv` (`:106-114`) defines the seven variables at `cacertFiltered`. `launchd.user.agents.ca-env-setenv` (`:612-624`) seeds the launchd user domain with `launchctl setenv` at login. One `nh switch` plus a logout applies it to GUI apps. Until that switch lands, a shell sees four of the seven variables.

## Affected: fails open when `NIX_SSL_CERT_FILE` is unset

Each tool refuses the chain while the variable points at the filtered bundle. Each one accepts it when the variable goes away and the tool falls back to `nss-cacert-3.108`.

| Package | On this host | First fixed | Declared | Status |
|---|---|---|---|---|
| node | 24.18.0 | 24.22.1 on 24.x, 22.23.4 on 22.x | `pi-coding-agent.nix:215,527,607`, `drpom.nix:76`, `argent.nix:15` | refuses under the filtered bundle. Accepts host A when unset |
| ruby (nix) | 3.4.9 | none found | none found | refuses under the filtered bundle. Accepts host A when unset |
| git | 2.55.0 | n/a. Defers to OpenSSL | `home-modules/git.nix:5` | refuses under the filtered bundle. Accepts host A when unset |
| cargo | 1.97.0 | n/a. Defers to libcurl | UNVERIFIED. `drpom.nix:157` only builds Rust | CONFLICTING. `CARGO_HTTP_CAINFO` at the filtered bundle refuses it, declared at `:112` |

Two measurements disagree on cargo. One run refused the chain with error 28. A later run accepted TLS and failed on the git content type. `CARGO_HTTP_CAINFO` pinning the 118-cert bundle refuses in both runs, so pin the variable and retest after each cargo bump.

`nss-cacert` carries both roots as plain anchors at index 39 and 145 of 150. No repo file declares it. Any tool that reads it instead of the filtered bundle fails open.

## Affected: upstream or vendor

| Package | On this host | First fixed | Declared | Status |
|---|---|---|---|---|
| go | 1.26.5 | 1.26.10 and 1.27.3, 20 Oct 2026 | `common.nix:280`, `neovim.nix:78` | no file store. `crypto/x509/root_darwin.go` reads Security.framework. Keychain contents UNVERIFIED |
| tailscale | absent on this host | 1.104.2, 21 Oct 2026. Fix rides on Go 1.27.3 | `nixos-modules/tailscale.nix:2` | MacMini runs none. Goofeus, GoofyEnvy, GoofyDesky and Ramsay still take nixpkgs 1.104.1 |
| webpki-roots | 1.0.9 | 1.0.10, 19 Oct 2026 | `vendor/mattgmak/lean-ctx` | lean-ctx pins 0.26.11 and 1.0.9. Bump both |

Tailscale bakes only Lets Encrypt ISRG roots into `net/bakedroots`. Its exposure comes from the Go toolchain, so the fix arrives with the Go bump inside the release. No host in this flake ships 1.104.2 today.

## Cleared

Do not re-audit these. Each one refuses the leaked chain.

| Package | Version | Why it clears |
|---|---|---|
| curl (nix) | 8.21.0 | OpenSSL backend, follows the filtered bundle. Exit 60 |
| curl (system) | 8.7.1 SecureTransport | Refuses with exit 60. Keychain contents UNVERIFIED, so this is a runtime result only |
| python3 (nix, via uv) | 3.12.0 | Reads `/private/etc/ssl/cert.pem`, 126 certs, neither root. Refuses |
| rustc | 1.97.0 | Offline compiler, no store |
| openssl | 3.6.3 | No store of its own. Follows `NIX_SSL_CERT_FILE`, then the nix profile bundle |
| `/etc/ssl/cert.pem` | Apple, 126 certs | Both roots absent |
| filtered bundle | `/nix/store/08w7jj2…-ca-certificates.crt` | 118 anchors, neither revoked CN. The reject-marked `aux` entries stay in `/etc/ssl/certs/ca-certificates.crt` |
| certifi | absent | No nix python, no Homebrew certifi module. Threshold 2026.10.19 does not apply here |
| java (Zulu 17) | 17.0.20 | Both aliases deleted from the real `cacerts`. 111 to 109 entries, sha256 `b88b8d1e…`, mtime 2026-10-22 11:54:38. Both hosts now fail PKIX path building while TLS still completes |
| ruby (Homebrew) | 4.0.7_1 | Keg upgrade. Loads 188 CAs from `openssl@4/cert.pem`, neither root |
| gem (Homebrew) | 4.0.20 | Same clean keg. 4.0.16 trusted the chain before the upgrade |
| python3 (Homebrew) | 3.14.9 | Same clean keg. 3.14.7 trusted the chain before the upgrade |
| kubectl, terraform, aws, gcloud, az, doctl, hcloud, flyctl | absent | No binary on `PATH`. `kubectl` is a broken symlink into Docker.app |

The Java fix was two `keytool` deletes against the real store:

```bash
keytool -delete -alias comodoaaaca -cacerts
keytool -delete -alias emsigneccrootcag3 -cacerts
```

A JDK reinstall restores both aliases, so rerun the deletes after a Zulu update.

## Open item: bun has no fixed release yet

Bun 1.3.13 still bundles `emSign ECC Root CA - G3` as a DER blob, so no plaintext subject exists in the binary and a file audit cannot see it. Commit `ea6a2c7` (20 Oct 2026) pruned four emSign roots from the bundled store. No tag carries it, and the newest release is 1.4.3.

No environment variable gives a runtime override. Bun 1.3.13 returned 200 with `SSL_CERT_FILE` at the filtered bundle. It returned 200 again with `SSL_CERT_FILE` at a path that does not exist, so bun validates against the compiled-in emSign root. The system bundle refused with `UNABLE_TO_GET_ISSUER_CERT`, which is not a fix. The release is the only repair.

Check after each bun bump:

```bash
bun -e "fetch('https://dv-g3b-emudhra.we-have-a-problem.com/').then(r=>console.log('exposed',r.status)).catch(e=>console.log('safe',e.code||e.message))"
```

`exposed 200` means the pin is still vulnerable. A certificate error means safe.

## Pending: node version

Node needs 24.22.1 on the 24.x line, or 22.23.4 on 22.x. The 21 Oct 2026 release updated bundled roots to NSS 3.131.1 and rejects chains with blocked keys. The bump is hygiene while `NIX_SSL_CERT_FILE` stays set, and it is a real fix once that variable goes missing.

Node honors both `NIX_SSL_CERT_FILE` and `SSL_CERT_FILE` through its nixpkgs OpenSSL link. An earlier note here claimed `SSL_CERT_FILE` alone does nothing. That claim was wrong. Isolated runs on node 24.18.0:

| Env | Result |
|---|---|
| `NIX_SSL_CERT_FILE` = filtered bundle | refused, `INVALID_PURPOSE` |
| `NIX_SSL_CERT_FILE` unset | exposed, 200 |
| `SSL_CERT_FILE` = filtered bundle | refused, `INVALID_PURPOSE` |
| both unset | exposed, 200 |
| `NIX_SSL_CERT_FILE` = `nss-cacert` bundle | exposed, 200 |

No reachable pin carries 24.22.1:

| Source | Date | nodejs_24 |
|---|---|---|
| root nixpkgs (`e72e4f2`) | 2026-08-04 | 24.21.0 |
| multiverse index (`8d6a14c`) | newest rev 2026-10-20 | 24.21.0 |
| nixpkgs `staging` (`fe575ea7`) | 2026-10-21 | 24.22.1, uncached |

`dendritic/mv.nix` holds `daysBehind "2026-08-13" 14`, and the bumped multiverse index stops one day short of the fix. When nixos-unstable ships 24.22.1, add a second anchor there and draw node from it. Do not use the `staging` rev: cache.nixos.org does not carry it.

## Gap: Droid

`dendritic/hosts/Droid.nix` imports neither `ca-trust.nix` nor `tailscale.nix`. Goofeus, GoofyDesky, GoofyEnvy and Ramsay import both, and `dendritic/iso/minimal.nix` imports `ca-trust.nix`. Judgement: nix-on-droid cannot use `security.pki`, because the Android target carries no NixOS PKI module.

## Unverified

- Go. No clean probe path, and the `security` command stays blocked. Keychain contents unknown.
- Apple keychain, which also serves system curl.
- Cargo default trust path. Two runs disagree, see above.
- Zulu 17 first fixed build. No release check done. The store is clean by hand, so this no longer blocks.
- `keytool` direct output. The shell allowlist blocks it. `cacerts` was read through the Java KeyStore API instead.
- `gem` remote probe. The `gem` binary is blocked, so only `Gem::VERSION` was read.

## Verify

```bash
bash scripts/check-ca-trust.sh
sudo tail -n 20 /var/log/fix-ssl-cert-pem.log
/usr/bin/curl -s -o /dev/null https://dv-g3b-emudhra.we-have-a-problem.com/; echo $?
node -e "require('https').get('https://dv-g3b-emudhra.we-have-a-problem.com/',()=>console.log('exposed')).on('error',e=>console.log('safe',e.code))"
bun -e "fetch('https://dv-g3b-emudhra.we-have-a-problem.com/').then(r=>console.log('exposed',r.status)).catch(e=>console.log('safe',e.code||e.message))"
```

Exit `0` from curl means exposed. `60` means the client refuses the compromised chain.

`scripts/check-ca-trust.sh` covers the bundle file, the Apple store and curl only (`:46-90`). The online probe runs curl alone, so it cannot catch the bun exposure. It does not probe node, bun, uv, Homebrew ruby or python3, Java, or go.
