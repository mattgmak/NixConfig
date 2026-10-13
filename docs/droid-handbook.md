# Droid handbook

Nix-on-Droid on the physical phone (Pixel 8 Pro, aarch64, serial `39061FDJG007P4`). Everything needed to rebuild from a fresh app install, plus every pitfall hit so far. Emulator-specific notes at the end.

## Architecture

- Host config: `dendritic/hosts/Droid.nix` — flake output `nixOnDroidConfigurations.default` (aarch64, `mv.unstable` pkgs).
- Toolchain pins: nix-on-droid `release-24.05`, nixpkgs-droid `24.05`. Do not bump nixpkgs-droid without testing — 25.11 breaks HM/stateVersion eval against the 24.05 modules.
- Phone's Nix is 2.18 (stock bootstrap): **cannot evaluate our flake** (`inputs.self.submodules` is a newer-Nix attribute). The phone can only realise pre-built store paths. Builds happen host-side; the phone pulls binaries.
- Upstream #545: `activationPackage` eval requires `--impure` (hardcoded proot-static store paths).

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
```

On the phone:

1. Install the Nix-on-Droid app (F-Droid). First run downloads a bootstrap zip — the stock APK defaults to `bootstrap-release-23.11`, which **404s for aarch64-less channels**; if prompted, set the bootstrap URL to `https://nix-on-droid.unboiled.info/bootstrap-release-24.05`. Answer **N** to the flakes prompt.
2. The stock bootstrap lands on a bare bash shell. The generation must be pulled and activated manually — `nix-on-droid switch` cannot work yet (see pitfalls).

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

# 5. Manual activation trio — full `nix-on-droid switch`/generation activate
#    dies at installPackages ("getting pseudoterminal attributes: Permission
#    denied"); these three steps are what actually works. Extract paths from
#    the gen's activate script and copy args verbatim:
grep -oE '/nix/store/[^ ]*-home-manager-generation/activate' "$GEN/activate"
grep -oE '/nix/store/[^ ]*-setup-etc.sh' "$GEN/activate"

export TMPDIR=/tmp HOME_MANAGER_BACKUP_EXT=hm-backup
bash /nix/store/<hash>-home-manager-generation/activate   # args from activate script
TMPDIR=/tmp bash /nix/store/<hash>-setup-etc.sh /etc <gen-etc-path> .bak

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
ls -la ~/.termux/font.ttf            # symlink → IosevkaTermNerdFont-Regular.ttf
ls -la ~/.local/state/agenix/        # all secrets present, 0400
time zsh -i -c exit                  # ~3 s, not ~25 s
```

## Redeploying a new generation (no reset)

Same as steps 3–7 above, but skip the keygen unless the identity changed. The reliable loop: build host → `nix-store --realise` on phone → HM activate + setup-etc → `nix-env --set` both profiles → force-stop + reopen.

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
- Root-only secrets (agent-age-key, cloudflare-caddy, handmux-token, …) are NOT encrypted to `Droid` and are not deployed to the phone.
- The phone's private key exists **only in app data** — app reset = new key = rekey required.

## Pitfalls (all encountered, all real)

1. **`nix-on-droid switch` / `generation activate` fails** at installPackages: `getting pseudoterminal attributes: Permission denied` (proot PTY limit). Always use the manual activation trio.
2. **`TMPDIR=/data/local/tmp` leak**: adb/app sessions export an unwritable TMPDIR; every nix/HM command needs `env TMPDIR=/tmp` or a shell-level `export`.
3. **`.zshenv` secret poll**: interactive shells wait up to 300×10 ms for the first secret file. If decryption is broken (stale recipient), every shell start burns the full loop → ~25 s prompt. Symptom of broken agenix, not a zsh bug.
4. **Non-interactive login shell**: nix-on-droid's `login-inner` execs zsh without `-i`; under proot isatty(0) fails even on a real pts, so `.zshrc` is skipped → no prompt. Fixed by the `profileExtra` re-exec guard in `zsh.nix` (`exec zsh -l -i`, `_NOD_REEXEC` sentinel).
5. **agenix mount**: agenix's HM module decrypts via a systemd user service and stores under `XDG_RUNTIME_DIR`. Android has no systemd and leaves `XDG_RUNTIME_DIR` empty → everything would hit the nonexistent `/agenix`. Fixed by `age.secretsDir = ${HOME}/.local/state/agenix` in `Droid.nix` + the `agenixMount` activation step.
6. **Stale Droid recipient**: the pubkey recorded in `secrets.nix` was from an older install; the phone had no matching private key → all secret decrypts failed silently (empty exports). Recipients must be regenerated+rekeyed after every app reset.
7. **compinit abort**: root-owned store dirs in fpath fail compaudit under the app uid; every new shell prompts `[y/n]` and aborts completions. Fixed with `compinit -u` (`Droid.nix` overrides `completionInit`).
8. **`shasum` missing**: compdump hash used `shasum` (perl); droid env has no perl → `.zshrc:30: command not found: shasum`. Fixed to `md5sum` in `zsh.nix`.
9. **Terminal font**: stock app font, no Iosevka. `terminal.font` in `Droid.nix` (`lib.mkForce` — Stylix also defines it) links `~/.termux/font.ttf` via the gen's `linkFont` activation step. Option shape verified against upstream `modules/terminal.nix` (`types.path`).
10. **proot-termux-static substitution**: upstream hardcodes aarch64 proot store paths (#545); only `https://nix-on-droid.cachix.org` carries them. Already in `Droid.nix` substituters + host `nix-config.nix`. Removing it breaks aarch64 eval/build.
11. **Remote builders**: `ssh-ng` builders in `nix.extraOptions` break HM activation on Termux (same PTY error). Keep disabled.
12. **`nix-env --install` is broken** on-device (PTY error building `user-environment.drv`); profile is managed via `--set` only. `nix-env -q` shows nothing — that's expected.
13. **yazi cross-build flakiness**: aarch64 yazi (mlua-sys) can ICE under qemu-binfmt (`Illegal instruction` in gcc). Auto-retry the build — transient.
14. **adb cannot touch app data**: no root, app not debuggable. File access from host goes through the exported DocumentsProvider: `content://com.termux.nix.documents/document/<%2F-encoded abs path>` (root = `/data/data/com.termux.nix/files/home`, no path validation). `content write` overwrites at offset 0 **without truncate** — empty the file first or write whole files.
15. **login-inner is read-only** (`r--r--r--`): run as `sh <path>`, never exec directly. If patching the `login` wrapper for recon payloads, always restore it byte-identical (md5 `f0073d67fbc36cc278adf3c7c8653967`, 2036 B).
16. **No git/curl in stock bootstrap** — the 24.05 bootstrap profile ships only nix-on-droid itself. Use `nix-shell -p git` or rely on the flake's `environment.packages` after activation.

## Emulator (x86-avd) — for testing without the phone

- `nixOnDroidConfigurations.x86-avd` = x86_64 variant (`mv.unstable` x86_64 pkgs). Same manual-activation flow, substituter `http://10.0.2.2:8181` from inside the AVD.
- API 36 images SIGSEGV the stock APK (SELinuxUtils crash) — use API 30 x86_64 `google_apis`. Emulator must launch with `-grpc <port> -grpc-use-token` for argent discovery.
- First bootstrap downloads ~112 MB and extracts ~44 min (I/O-bound); guest egress over slirp is glacial — always serve the host store instead of cache.nixos.org.

## Quick reference

| Task | Command |
|---|---|
| Build gen (host) | `nix build .#nixOnDroidConfigurations.default.activationPackage --impure --no-link --print-out-paths` |
| Serve store | `tmux new-session -d -s nixserve "nix run nixpkgs#nix-serve-ng -- --port 8181"` |
| Pull gen (phone) | `nix-store --realise $GEN --option substituters http://192.168.50.107:8181 --option trusted-substituters http://192.168.50.107:8181 --option require-sigs false` |
| Rekey secrets (host) | `cd secrets && RULES=./secrets.nix agenix -r -i ~/.ssh/id_ed25519` |
| Rollback (phone) | `nix-on-droid rollback` (works — only profile repoint; or manual `nix-env --set` of prior gen) |
