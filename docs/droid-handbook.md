# Droid handbook

Nix-on-Droid on the physical phone (Pixel 8 Pro, aarch64, serial `39061FDJG007P4`). Everything needed to rebuild from a fresh app install, plus every pitfall hit so far. Emulator-specific notes at the end.

## Architecture

- Host config: `dendritic/hosts/Droid.nix` — flake output `nixOnDroidConfigurations.default` (aarch64, `mv.unstable` pkgs).
- Toolchain pins: nix-on-droid **master** (@ `df611d53`, 2026-08-21), nixpkgs-droid `24.05`. Do not bump nixpkgs-droid without testing — eval breaks against newer droid modules.
- Phone's Nix is now **2.34.8** (gen's nix-on-droid-path replaced the bootstrap 2.18). The bootstrap Nix 2.18.8 **cannot evaluate our flake** (`inputs.self.submodules` and path-valued `url = ./vendor/...` both rejected — needs Nix ≥2.19). New-gen workflow: host realises fresh gen from local nix-serve once per fresh device; afterwards the phone can `nix-on-droid switch --flake .` fully on-device — no host nix-serve beyond the bootstrap-gen realise.
- Upstream #545: `activationPackage` eval requires `--impure` (hardcoded proot-static store paths).
- **Proot TCGETS2 fix** (upstream PR #529, commit `dff2d1e`): glibc ≥2.42's tcgetattr uses the TCGETS2 ioctl; old proot didn't rewrite it and Android SELinux denies it → `getting pseudoterminal attributes: Permission denied` killed every on-device build. Patched proot-static rewrites TCGETS2→TCGETS. Shipped with master: aarch64 proot `dvf2ck9b…` (sha256 `713eb72b…`, 1054208 B), x86_64 `w7fksni0…` (sha256 `47243d24…`, 1080712 B). Both substitutable from nix-on-droid.cachix.org.
- **Ordering trap**: gen activation runs `installPackages` BEFORE `installProotStatic`. With the old broken proot, the first on-device switch still dies at installPackages before proot can update → seed patched proot manually once: realise gen, `install -m755 <gen-patched-proot>/bin/proot-static $PREFIX/bin/.proot-static.new`, close ALL app windows, reopen → proot swaps.
- **Flake-eval chicken/egg**: from a bare (wiped) bootstrap, `nix-on-droid switch --flake .` with our repo flake fails at eval (bootstrap Nix 2.18). Fix: realise the master-driven gen first, then run the switch with the gen's Nix on PATH:
  ```bash
  env PATH="$GEN/nix-on-droid-path/bin:$PATH" nix-on-droid switch --flake .#<target> --option substituters http://<host>:8181 --option trusted-substituters http://<host>:8181 --option require-sigs false
  ```
  On a real phone this PATH trick is unnecessary once the profile already points at a master gen (the phone's default Nix resolves from the live profile).

## Fresh-install bootstrap

Prerequisites on host (`GoofyDesky`, LAN IP `192.168.50.107`, Tailscale `100.99.44.71`):

```bash
# 1. Serve the host store on the LAN (port 8181 is firewalled-open in common.nix).
tmux new-session -d -s nixserve \
  "nix run nixpkgs#nix-serve-ng -- --port 8181 2>&1 | tee /tmp/agent-tmp/nixconfig/nix-serve.log"

# 2. Build the phone's generation host-side (--impure required, upstream #545).
cd ~/NixConfig
nix build .#nixOnDroidConfigurations.default.activationPackage \
  --impure --no-link --print-out-paths
# → /nix/store/<hash>-nix-on-droid-generation   (call this $GEN)
# Sanity: nix-store -qR $GEN | grep proot   → dvf2ck9b… (patched, 2026-02-20),
#         NOT 7qd99m1w65x2vgqg453nd70y60sm3kay…2024-05-04 (broken proot).
```

On the phone:

1. Install the Nix-on-Droid app (F-Droid). First run downloads a bootstrap zip — the stock APK defaults to `bootstrap-release-23.11`, which **404s for aarch64-less channels**; if prompted, set the bootstrap URL to `https://nix-on-droid.unboiled.info/bootstrap-release-24.05`. Answer **N** to the flakes prompt.
2. The stock bootstrap lands on a bare bash shell. Realise the master gen from the host, then the activation trio (below) repoints the profile; after that the phone can switch natively.

```bash
# Inside the phone shell (proot). $GEN is the host-built generation path.
HOST=http://192.168.50.107:8181
GEN=/nix/store/<hash>-nix-on-droid-generation
export TMPDIR=/tmp   # adb/app sessions leak TMPDIR=/data/local/tmp (unwritable)

# 3. Pull the closure from the host.
nix-store --realise "$GEN" \
  --option substituters http://$HOST:8181 \
  --option trusted-substituters http://$HOST:8181 \
  --option require-sigs false

# 4. Generate the device age identity + record its pubkey.
mkdir -p ~/.ssh && chmod 700 ~/.ssh
ssh-keygen -t ed25519 -N '' -f ~/.ssh/id_ed25519
cat ~/.ssh/id_ed25519.pub
# → put this key as `Droid` in dendritic/ssh-keys.nix AND the `let` block of
#   secrets/secrets.nix, then rekey (see "Secrets" below) BEFORE activating:
#   cd secrets && RULES=./secrets.nix agenix -r -i ~/.ssh/id_ed25519
#   (host side; -i is any identity that can decrypt, e.g. GoofyDesky user key)

# 5. Manual activation trio — extract paths from the gen's activate script and
#    copy args verbatim:
grep -oE '/nix/store/[^ ]*-home-manager-generation/activate' "$GEN/activate"
grep -oE '/nix/store/[^ ]*-setup-etc.sh' "$GEN/activate"

export TMPDIR=/tmp HOME_MANAGER_BACKUP_EXT=hm-backup
bash /nix/store/<hash>-home-manager-generation/activate
TMPDIR=/tmp bash /nix/store/<hash>-setup-etc.sh /etc <gen-etc-path> .bak

# /etc/passwd survived setup-etc with only nix-on-droid:x:1000 — proot runs as
# Android uid 10839, ssh needs the entry. Append a uid-10839 passwd line.
# Without it: ssh aborts pre-auth with 'No user exists for uid 10839'.

# 6. Point both profiles at the new generation.
nix-env --profile "$HOME/.nix-profile" --set "$GEN/nix-on-droid-path"
nix-env --profile /nix/var/nix/profiles/nix-on-droid --set "$GEN"

# 7. Force-stop the app, reopen. The .zprofile re-exec guard makes the login
#    shell interactive; starship prompt should render in ~3 s.
```

Post-boot verification:

```bash
echo $-                 # must contain i
echo ${#PROMPT}         # 273
ls -la ~/.termux/font.ttf            # REAL FILE (not symlink into /nix/store)
sha256sum /data/data/com.termux.nix/files/usr/bin/proot-static   # 713eb72b…
nix --version            # 2.34.8 on master-gen
cat ~/.ssh/config        # goofeus block present
ls -la ~/.local/state/agenix/        # all secrets present, 0400
time zsh -i -c exit                  # ~3 s, not ~25 s
```

## Redeploying a new generation (no reset)

Same as steps 3–7, but skip the keygen unless the identity changed. Reliable loop: build host → `nix-store --realise` on phone → HM activate + setup-etc (+ passwd uid-10839 line) → `nix-env --set` both profiles → force-stop + reopen. Once the phone is on a master gen, repeat switches can run fully on-device (`nix-on-droid switch --flake .`) with no nix-serve beyond the bootstrap-gen realise.

## SSH from phone to hosts

- `~/.ssh/config` must include a `goofeus` block → `User agent` (goofy does NOT exist on goofeus; valid users: `agent`, `root`), `HostName 100.111.11.128` (Tailscale; plain `goofeus` name also works once `/etc/resolv.conf` exists), `IdentityFile ~/.ssh/id_ed25519`.
- If it's a dangling symlink into a GC'd store path → write a real file, `chmod 600`. Durable repo fix = add `programs.ssh.matchBlocks.goofeus` in `Droid.nix`.
- Seed `known_hosts` on-device: `ssh-keyscan -H <hostname-or-ip> > ~/.ssh/known_hosts`.
- `/etc/resolv.conf` missing breaks in-proot DNS (`getaddrinfo: Name or service not known`) — pin the Tailscale IP in config as a workaround until `/etc` is repaired.
- Verify: `ssh goofeus echo ok` → `ok`, EXIT=0. Phone key (`droid@Droid`) works for both `agent@goofeus` and `root@goofeus`.

## Secrets (agenix)

- Recipient for the phone is the `Droid` var — defined **twice**: `dendritic/ssh-keys.nix` and the `let` block of `secrets/secrets.nix`. Keep them identical.
- 10 pi API secrets (cline, cursor, github-mcp, openrouter, …) list `Droid` as a recipient.
- Rekey after changing any recipient:

```bash
cd ~/NixConfig/secrets
RULES=./secrets.nix agenix -r -i ~/.ssh/id_ed25519   # host-side; decryptor identity first
```

- Decryption on-device happens in the HM activation step `agenixMount` (`dendritic/home-modules/zsh/zsh.nix`): plain `age -d -i ~/.ssh/id_ed25519` per secret into `$HOME/.local/state/agenix/`. agenix's own mount path is unusable (see pitfalls).
- Decrypt test syntax: `agenix -i KEY -d FILE` (NOT `agenix -d -i KEY FILE` — prints help).
- Root-only secrets (agent-age-key, cloudflare-caddy, …) are NOT encrypted to `Droid` and are not deployed to the phone.
- The phone's private key exists **only in app data** — app reset = new key = rekey required.

## Pitfalls (all encountered, all real)

1. **Old proot PTY failure — FIXED by master pin** (release-24.05 era): `getting pseudoterminal attributes: Permission denied` at installPackages. Root cause = glibc ≥2.42's tcgetattr uses TCGETS2; Android SELinux denies, old proot doesn't rewrite. Fix = patched proot (see Architecture). Manual trio was the workaround; with master + patched proot, on-device `nix-on-droid switch` works verbatim (verified on emulator gen 3 and on the phone).
2. **`TMPDIR=/data/local/tmp` leak**: adb/app sessions export an unwritable TMPDIR; every nix/HM command needs `env TMPDIR=/tmp` or a shell-level `export`.
3. **`.zshenv` secret poll**: interactive shells wait up to 300×10 ms for the first secret file. If decryption is broken (stale recipient), every shell start burns the full loop → ~25 s prompt. Symptom of broken agenix, not a zsh bug.
4. **Non-interactive login shell**: nix-on-droid's `login-inner` execs zsh without `-i`; under proot isatty(0) fails even on a real pts, so `.zshrc` is skipped → no prompt. Fixed by the `profileExtra` re-exec guard in `zsh.nix` (`exec zsh -l -i`, `_NOD_REEXEC` sentinel).
5. **agenix mount**: agenix's HM module decrypts via a systemd user service and stores under `XDG_RUNTIME_DIR`. Android has no systemd and leaves `XDG_RUNTIME_DIR` empty → everything would hit the nonexistent `/agenix`. Fixed by `age.secretsDir = ${HOME}/.local/state/agenix` in `Droid.nix` + the `agenixMount` activation step.
6. **Stale Droid recipient**: the pubkey recorded in `secrets.nix` was from an older install; the phone had no matching private key → all secret decrypts failed silently (empty exports). Recipients must be regenerated+rekeyed after every app reset.
7. **compinit abort**: root-owned store dirs in fpath fail compaudit under the app uid; every new shell prompts `[y/n]` and aborts completions. Fixed with `compinit -u` (`Droid.nix` overrides `completionInit`).
8. **`shasum` missing**: compdump hash used `shasum` (perl); droid env has no perl → `.zshrc:30: command not found: shasum`. Fixed to `md5sum` in `zsh.nix`.
9. **Terminal font / DRAWER / colors as real files**: HM `home.file` makes *store symlinks*, but the Android app process runs OUTSIDE proot with no `/nix` mount — so `~/.termux/font.ttf`, `termux.properties`, `colors.properties` never resolve for the app and it silently falls back to built-in defaults (wrong font, no DRAWER key, wrong colors). The store paths aren't GC'd — /nix itself is invisible to the app. Fix: materialise **real files** via a `home.activation` copy step (like `agenixMount`). Beware HM activation moves real files to `*.hm-backup*` and re-creates symlinks — the activation step must run AFTER `writeBoundary` on every gen.
10. **proot-termux-static substitution**: upstream hardcodes aarch64 proot store paths (#545); only `https://nix-on-droid.cachix.org` carries them. Already in `Droid.nix` substituters + host `nix-config.nix`. Removing it breaks aarch64 eval/build.
11. **Remote builders**: `ssh-ng` builders in `nix.extraOptions` break HM activation on Termux (same PTY error). Keep disabled.
12. **`setup-etc` order**: must run AFTER HM activate; verify `ls /etc` shows a real directory (passwd, hosts, resolv.conf, static, …), NOT `lrw-r--r-- … /etc -> /system/etc`. Wrong body → `/etc/passwd` missing → ssh `No user exists for uid 10839`, DNS dead.
13. **`/etc/passwd` Android uid**: setup-etc ships only `nix-on-droid:x:1000`; proot runs as uid 10839, so ssh aborts pre-auth until a 10839 entry is appended (post-setup-etc, replace the store symlink with a real file first).
14. **yazi cross-build flakiness**: aarch64 yazi (mlua-sys) can ICE under qemu-binfmt (`Illegal instruction` in gcc). Auto-retry the build — transient.
15. **adb cannot touch app data**: no root, app not debuggable. File access from host goes through the exported DocumentsProvider: `content://com.termux.nix.documents/document/<%2F-encoded abs path>` (root = `/data/data/com.termux.nix/files/home`, no path validation). `content write` overwrites at offset 0 **without truncate** — empty the file first or write whole files.
16. **login-inner is read-only** (`r--r--r--`): run as `sh <path>`, never exec directly. If patching the `login` wrapper for recon payloads, always restore it byte-identical (md5 `f0073d67fbc36cc278adf3c7c8653967`, 2036 B).
17. **No git/curl in stock bootstrap** — the 24.05 bootstrap profile ships only nix-on-droid itself. Use `nix-shell -p git` or rely on the flake's `environment.packages` after activation.
18. **post-deploy GC chop**: host GC can prune store paths the phone's HM symlinks point at → dangling `~/.zshrc`, `~/.ssh/config`, `~/.termux/*`, dead `/etc/static/*`. Re-running the activation trio from the SAME gen (realise → setup-etc → HM activate) re-materialises from live store paths. After ANY host GC, verify `~/.zshrc` resolves before switching.

## Emulator (x86-avd)

- `nixOnDroidConfigurations.x86-avd` = x86_64 variant (`mv.unstable` x86_64 pkgs). Same manual-activation flow, substituter `http://10.0.2.2:8181` from inside the AVD.
- API 36 images SIGSEGV the stock APK (SELinuxUtils crash) — use API 30 x86_64 `google_apis`. Emulator must launch with `-grpc <port> -grpc-use-token` for argent discovery.
- First bootstrap downloads ~112 MB and extracts ~44 min (I/O-bound); guest egress over slirp is glacial — always serve the host store instead of cache.nixos.org.
- Emulator window class is `Emulator` (XWayland Qt app, not qemu-*). Hyprland rules in `dendritic/home-modules/hyprland/lua/window-rules.nix`: `class = "(Emulator)"` → float+center+pin (all hosts), workspace 6 (Desky only).
- Emulator E2E (2026-10-17): master gen `yysshwyc…` realised from local nix-serve; patched proot swapped (sha `47243d24…`); plain `nix-on-droid switch --flake .#x86-avd` with gen Nix 2.34.8 → RC=0, profile bumped to our repo gen — **zero PTY errors**; second rebuild (with a harmless zshrc marker edit) also RC=0 (54s), bumping gen again. Validated the whole on-device rebuild loop.
- Manual bootstrap debugging on a wiped AVD: SELinux — symlinks created via plain `adb shell` (shell uid) inside app-private dirs get EACCES for the app uid; proot misleadingly reports ENOENT (`bin/sh not found`). Fix: recreate symlinks as the app uid via `run-as com.termux.nix`.
- Hand-unpacked bootstrap needs app-uid ownership of `etc/` and `usr/lib` too, else upstream's setUpEtc prompts interactively and wedges activation.
- Emulator bootstrap installer refuses cleartext HTTP (`Cleartext HTTP traffic to 10.0.2.2 not permitted`) — host HTTP bootstrap URLs don't work in-app; unpack manually instead.

## Quick reference

| Task | Command |
|---|---|
| Build gen (host) | `nix build .#nixOnDroidConfigurations.default.activationPackage --impure --no-link --print-out-paths` |
| Verify patched proot in gen | `nix-store -qR $GEN \| grep proot` → `dvf2ck9b…` |
| Serve store | `tmux new-session -d -s nixserve "nix run nixpkgs#nix-serve-ng -- --port 8181"` |
| Pull gen (phone) | `nix-store --realise $GEN --option substituters http://192.168.50.107:8181 --option trusted-substituters http://192.168.50.107:8181 --option require-sigs false` |
| On-device switch (master gen) | `TMPDIR=/tmp environment PATH="$GEN/nix-on-droid-path/bin:$PATH" nix-on-droid switch --flake .#default --option substituters … --option require-sigs false` |
| Verify ssh (phone) | `ssh goofeus echo ok` |
| Rekey secrets (host) | `cd secrets && RULES=./secrets.nix agenix -r -i ~/.ssh/id_ed25519` |
| Rollback (phone) | `nix-on-droid rollback` (works — only profile repoint; or manual `nix-env --set` of prior gen) |
