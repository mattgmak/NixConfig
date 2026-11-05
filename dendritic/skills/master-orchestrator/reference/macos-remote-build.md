# macOS remote iOS build

The iOS app builds on the remote Mac mini. This Linux host runs no Xcode.

## Host

- Host: `mattgmak@macmini`.
- macOS 27.0.1, build 26A434.
- Xcode 26.5, build 17F42.
- Simulator runtime: iOS 26.5.

## Build tree

All build state sits on the external drive, under `/Volumes/Kingston480GB/tcm-build/`.

| Path | Holds |
|---|---|
| `repo` | the checkout |
| `DerivedData` | Xcode products and intermediates |
| `store` | the pnpm store |
| `logs` | build logs and screenshots |
| `artifacts` | the `.app` bundle |
| `npm-global` | the pnpm binary |

Xcode writes DerivedData to the home folder by default. Link it to the external drive:

```bash
ln -sfn /Volumes/Kingston480GB/tcm-build/DerivedData ~/Library/Developer/Xcode/DerivedData
```

## pnpm

`pnpm` 12.16.1 sits in `npm-global`, because `corepack enable` fails on the read-only nix profile.

```bash
npm i -g pnpm --prefix /Volumes/Kingston480GB/tcm-build/npm-global
export PATH=/Volumes/Kingston480GB/tcm-build/npm-global/bin:$PATH
```

## Install

Run the install with no scripts:

```bash
pnpm install --ignore-scripts --store-dir /Volumes/Kingston480GB/tcm-build/store
```

The `uniwind-pro` package (`npm:uniwind@npm:uniwind-pro@1.9.0`) runs a postinstall that needs a token. The token guards a download, so a scripted install fails.

Copy the payload from a host that already holds it into the same `.pnpm` path on the mini:

```bash
tar czf - -C node_modules/.pnpm/<uniwind-pro path> . \
  | ssh mattgmak@macmini 'tar xzf - -C /Volumes/Kingston480GB/tcm-build/repo/node_modules/.pnpm/<uniwind-pro path>'
```

Skia 2.14.0 needs no manual step. Its xcframeworks ship in `react-native-skia-apple-ios`. `pod install` copies them into `libs/ios`. The package has no `scripts/install-libs.js`.

## Scheme and workspace

The scheme is `app`. The workspace is `app.xcworkspace`. The scheme is not `tcm-app`.

## Build

Run from the workspace folder:

```bash
cd /Volumes/Kingston480GB/tcm-build/repo/apps/tcm-app/ios
xcodebuild -workspace app.xcworkspace -scheme app -sdk iphonesimulator \
  -configuration Debug -derivedDataPath /Volumes/Kingston480GB/tcm-build/DerivedData build
```

For a Release build, run the same command with `-configuration Release`. A Release build embeds `main.jsbundle`, so the app runs with no Metro.

## Reuse the installed dev client

Build only when the native layer changed. A JS-only change needs no build, because the dev client reads its bundle from Metro.

Ask two questions first, on the mini:

```bash
xcrun simctl list devices booted
xcrun simctl get_app_container <udid> net.drpom.easy-tcm app
```

A non-zero exit from the second command means no dev client. Both answers must hold. The simulator holds the app for the bundle id. The ledger fingerprint equals the current native fingerprint.

Read the ledger for that simulator:

```bash
cat /Volumes/Kingston480GB/tcm-build/native/<udid>.json
```

Compute the current native fingerprint from the native inputs:

```bash
native_fingerprint() {
  cd /Volumes/Kingston480GB/tcm-build/repo/apps/tcm-app
  { shasum -a 256 ios/Podfile.lock ios/app.xcodeproj/project.pbxproj app.config.ts
    sed -n '/"dependencies"/,/^  }/p' package.json | shasum -a 256
  } | shasum -a 256 | cut -c1-16
}
```

| Installed | Fingerprint equal | Action |
|---|---|---|
| no | any | build, install, write the ledger |
| yes | no | build, install, write the ledger |
| yes | yes | install nothing, start Metro, launch |

Write the ledger after each build, for the simulator that holds the new app:

```bash
mkdir -p /Volumes/Kingston480GB/tcm-build/native
printf '{"fingerprint":"%s","build_sha":"%s","stamp":"%s"}\n' \
  "$(native_fingerprint)" "$(git -C /Volumes/Kingston480GB/tcm-build/repo rev-parse HEAD)" \
  "$(date -u +%FT%TZ)" > /Volumes/Kingston480GB/tcm-build/native/<udid>.json
```

Report the fingerprint and the build sha in the evidence block. A later run then knows which native build a simulator holds.

## Install and launch

The bundle id is `net.drpom.easy-tcm`.

```bash
xcrun simctl install <device> <app>
xcrun simctl launch <device> net.drpom.easy-tcm
```

## Screenshot

`xcrun simctl io <device> screenshot /Volumes/...` fails with `Operation not permitted`. Write to `$HOME` first, then copy to the external drive.

```bash
xcrun simctl io <device> screenshot "$HOME/shot.png"
cp "$HOME/shot.png" /Volumes/Kingston480GB/tcm-build/logs/shot.png
rm "$HOME/shot.png"
```

## Clean the internals

Xcode puts its internals in `DerivedData/Build/Intermediates.noindex`. That folder reaches 12 GiB. Remove it after a build, and keep `Build/Products`.

## Disk floors

The internal `/` holds about 11 GiB free. One booted simulator takes 3 GiB. The external drive holds 28 GiB free. Stop at 5 GiB free on either disk.

## Move files off the Linux host

The shell policy on the Linux host denies `scp` and `base64`. Move files with tar over ssh:

```bash
tar czf - -C <dir> . | ssh mattgmak@macmini 'tar xzf - -C <target>'
```

Read a frame with `ctx_read`. A peer reads a screenshot with its own `ctx_read`, mode `full`. Never report that no tool reads pixels.

## Remote iOS build

The app builds on the Mac mini, never on this Linux host. Read `reference/macos-remote-build.md` before the first command.

A lane needs two facts before it starts:

- Run `pnpm install --ignore-scripts`. The `uniwind-pro` postinstall needs a token, so the scripted install fails.
- Every path sits under `/Volumes/Kingston480GB/tcm-build/`: `repo`, `DerivedData`, `store`, `logs`, `artifacts`, `npm-global`.
