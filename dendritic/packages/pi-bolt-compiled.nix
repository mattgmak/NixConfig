{ self, ... }:
{
  perSystem =
    { pkgs, system, ... }:
    let
      piCompiled = pkgs.callPackage (
        {
          lib,
          stdenv,
          fetchurl,
          gnutar,
          gzip,
          jq,
          xz,
          patchelf,
          makeWrapper,
          findutils,
          coreutils,
        }:
        let
          version = "1.0.4";

          # Three assets per system, all from this base:
          #   pi-bolt-<variant>.tar.xz            release app tree
          #   pi-bolt-runtime-<variant>.tar.gz    bun runtime the compiler drives
          #   pi-bolt-kit-<variant>.tar.gz        compile kit (patched Pi sources + node_modules)
          # App hashes are the pins from pi-bolt.nix. The runtime and kit hashes come from
          # `nix store prefetch-file --json <url>`.
          baseUrl = "https://github.com/opensec-git/Pi-Bolt/releases/download/bolt-v${version}";

          platformAttrs = {
            "x86_64-linux" = {
              variant = "linux-x64";
              appHash = "sha256-ZHglSWc3pgHGOaQbfqJy8V+MPs34yUzAjYhjM41O540=";
              runtimeHash = "sha256-ufFqNfSfVpDj6f0DNWFG0DhDaZhHxzSLJ8ww1wm+M7c=";
              kitHash = "sha256-8oOaBSenXD+eCm2woU546tgDLeFSZkEt9VTXzvsLm1A=";
            };
            "aarch64-darwin" = {
              variant = "darwin-arm64";
              appHash = "sha256-i+Z8R/h7FiH1IIUAs8VE2FIpM3MNf23lQZ17krzFXK0=";
              runtimeHash = "sha256-/c15MnQM0xns1kToDiWLcN4+1pRMHSTa0MNKGN23izA=";
              kitHash = "sha256-Q0eTyICBkF8uvk0asX8chq0g1yqQoW12aYVsqpK7nsU=";
            };
          };

          attrs =
            platformAttrs.${stdenv.hostPlatform.system}
              or (throw "pi-bolt-compiled: unsupported platform ${stdenv.hostPlatform.system}");

          # Loader folders whose dependencies the compile kit supplies, plus the ones
          # `npmDepRepos` below supplies.
          extensions = [
            "agent-ste"
            "filter-output"
            "gentle-engram"
            "pi-agent-browser-native"
            "pi-agent-sesh"
            "pi-away"
            "pi-blackhole"
            "pi-caveman"
            "pi-codegraph"
            "pi-commandcode-provider"
            "pi-cursor-sdk"
            "pi-cursor-usage"
            "pi-interactive-subagents"
            "pi-lean-ctx"
            "pi-markdown-preview"
            "pi-mcp-adapter"
            "pi-model-pick"
            "pi-nvim"
            "pi-nvim-bridge"
            "pi-opencode-go-usage"
            "pi-permission-system"
            "pi-powerline-footer"
            "pi-rewind"
            "pi-session-tools"
            "pi-simplify"
            "pi-web-access"
            "prompt-snippets"
            "rpiv-ask-user-question"
            "rpiv-todo"
            "tmax-status"
            "tool-allowlist"
          ];

          # Repos the loaders above import through ../vendor/<owner>/<repo>/...
          vendorRepos = [
            "arpagon/pi-rewind"
            "carderne/pi-nvim"
            "ctotheameron/agent-ste"
            "fgladisch/pi-extensions"
            "fitchmultz/pi-agent-browser-native"
            "fitchmultz/pi-cursor-sdk"
            "gotgenes/pi-packages"
            "juicesharp/rpiv-mono"
            "k0valik/pi-blackhole"
            "MattDevy/pi-extensions"
            "mattgmak/agent-sesh"
            "mattgmak/pi-interactive-subagents"
            "mattgmak/pi-nvim-bridge"
            "michalvavra/agents"
            "nicobailon/pi-mcp-adapter"
            "nicobailon/pi-powerline-footer"
            "nicobailon/pi-web-access"
            "omaclaren/pi-markdown-preview"
            "patlux/pi-commandcode-provider"
            "Pringled/pi-extensions"
            "theo-kirby/tmax"
            "vndv/pi-codegraph"
          ];

          # Repo source is the cache key. Copy one named subtree, minus generated
          # directories, so an unrelated edit keeps every key stable.
          srcOf = sub: builtins.path {
            name = "pi-ext-src";
            path = /. + builtins.unsafeDiscardStringContext "${self}/${sub}";
            filter = p: _: !(builtins.elem (baseNameOf p) [ ".git" "node_modules" ".engram-deps" ]);
          };

          extensionsDir = "${srcOf "dendritic/home-modules/pi-coding-agent/extensions"}";
          vendorRoot = "${srcOf "vendor"}";
          kitTree = "unpack/kit/tree";

          # Staged vendor contents that sit below a repo root. The whole repo would put
          # hundreds of MB into the stage that no loader reads.
          vendorSubdirs = [
            {
              repo = "Gentleman-Programming/engram";
              subdir = "plugin/pi";
            }
            {
              repo = "mattgmak/lean-ctx";
              subdir = "packages/pi-lean-ctx";
            }
          ];

          # Staged vendor dirs that import npm packages the kit does not carry. One line
          # per repo, installed offline from its own lockfile. A repo that fails to
          # build is one line to drop here plus its name from `extensions`.
          npmDepRepos = [
            "mattgmak/agent-sesh/extensions/pi-agent-sesh"
            "nicobailon/pi-mcp-adapter"
            "nicobailon/pi-web-access"
            "omaclaren/pi-markdown-preview"
          ];

          # These lockfiles record dev-only subtrees from bundled shrinkwraps, and those
          # entries carry no integrity, so importNpmLock cannot fetch them. Production
          # deps only: drop the dev entries and the manifest ranges that name them.
          prodLock = lock: lock // {
            packages = lib.filterAttrs (_: entry: !(entry.dev or false)) lock.packages;
          };

          npmNodeModules =
            {
              repo,
              devDeps ? false,
              extraFlags ? [ ],
              lockPatch ? (_: entry: entry),
              dropPackages ? (_: false),
              dropOverrides ? false,
              dropPeers ? false,
              keepDevDeps ? null,
            }:
            let
              root = srcOf "vendor/${repo}";
              manifest = lib.importJSON (root + "/package.json");
              lock = lib.importJSON (root + "/package-lock.json");
              patched = lock // {
                packages = lib.filterAttrs (
                  name: _: !(dropPackages name)
                ) (lib.mapAttrs lockPatch lock.packages);
              };
            in
            pkgs.importNpmLock.buildNodeModules {
              package =
                (
                  builtins.removeAttrs manifest (
                    lib.optional dropOverrides "overrides"
                    ++ lib.optional (!devDeps) "devDependencies"
                    ++ lib.optionals (dropPeers || !devDeps) [
                      "peerDependencies"
                      "peerDependenciesMeta"
                    ]
                  )
                )
                // lib.optionalAttrs (keepDevDeps != null) {
                  devDependencies = lib.filterAttrs (
                    name: _: builtins.elem name keepDevDeps
                  ) (manifest.devDependencies or { });
                };
              packageLock = if devDeps then patched else prodLock patched;
              nodejs = pkgs.nodejs;
              derivationArgs = {
                pname = "${builtins.baseNameOf repo}-node-modules${lib.optionalString devDeps "-dev"}";
                npmInstallFlags = (lib.optional (!devDeps) "--omit=dev") ++ extraFlags;
                npmRebuildFlags = [ "--ignore-scripts" ];
              };
            };

          # pi-cursor-sdk ships TypeScript, and its loader picks the specifier at run time,
          # so the bundler cannot follow that import. Bundle the package here and give the
          # kit the bundle as one extra entry; the compile then embeds it at
          # $bunfs/root/pi-bolt-bundle.js, where the loader's dynamic import lands. bun
          # reads the TypeScript directly, so the package's tsc build is not needed.
          cursorSdkBundle = pkgs.stdenv.mkDerivation {
            pname = "pi-cursor-sdk-bundle";
            version = "0";
            src = srcOf "vendor/fitchmultz/pi-cursor-sdk";
            nativeBuildInputs = [
              pkgs.nodejs
              # bunBin, not pkgs.bun: the global bun overlay used to poison every
              # derivation that takes bun, gleam included.
              self.packages.${system}.bunBin
            ];
            buildPhase = ''
              runHook preBuild
              cp -a ${npmNodeModules {
                repo = "fitchmultz/pi-cursor-sdk";
                extraFlags = [ "--legacy-peer-deps" ];
                # Three packages are peers here, so the lock records them without a
                # tarball and npm would look for a packument. Name the tarballs npm picks.
                lockPatch =
                  name: entry:
                  let
                    tarballs = {
                      "node_modules/zod" = {
                        pkg = "zod";
                        version = "3.25.76";
                        integrity = "sha512-gzUt/qt81nXsFGKIFcC3YnfEAx5NkunCfnDlvuBSSFS02bcXu4Lmea0AFIUwbLWxWPx3d9p8S5QoaujKcNQxcQ==";
                      };
                      "node_modules/@statsig/client-core" = {
                        pkg = "@statsig/client-core";
                        version = "3.31.0";
                        integrity = "sha512-SuxQD6TmVszPG7FoMKwTk/uyBuVFk7XnxI3T/E0uyb7PL7GNjONtfsoh+NqBBVUJVse0CUeSFfgJPoZy1ZOslQ==";
                      };
                      "node_modules/@statsig/js-client" = {
                        pkg = "@statsig/js-client";
                        version = "3.31.0";
                        integrity = "sha512-LFa5E0LjT6sTfZv3sNGoyRLSZ1078+agdgOA+Vm1ecjG+KbSOfBLTW7hMwimrJ29slRwbYDzbtKaPJo/R37N2g==";
                      };
                    };
                    t = tarballs.${name} or null;
                  in
                  if t == null then
                    entry
                  else
                    entry
                    // {
                      resolved =
                        "https://registry.npmjs.org/${t.pkg}/-/"
                        + "${builtins.baseNameOf t.pkg}-${t.version}.tgz";
                      inherit (t) integrity;
                    };
              }}/node_modules node_modules
              bun build src/index.ts \
                --target=bun --format=esm --outfile=pi-bolt-bundle.js \
                --external '@earendil-works/*' \
                --external '@mariozechner/*' \
                --external 'typebox*' \
                --external '@sinclair/typebox*' \
                --external '*.node'
              runHook postBuild
            '';
            installPhase = ''
              mkdir -p $out
              cp pi-bolt-bundle.js $out/
            '';
          };

          # pi-agent-browser-native ships TypeScript sources and a build script. The
          # published entry is dist/extensions/agent-browser/index.js, so the build runs
          # here from a lockfile install, and the stage phase gets that tree plus the
          # runtime deps its bundles leave external.
          agentBrowserNative = pkgs.stdenvNoCC.mkDerivation {
            pname = "pi-agent-browser-native-dist";
            version = "0";
            src = srcOf "vendor/fitchmultz/pi-agent-browser-native";
            nativeBuildInputs = [ pkgs.nodejs ];
            buildPhase = ''
              runHook preBuild
              cp -a ${npmNodeModules {
                repo = "fitchmultz/pi-agent-browser-native";
                devDeps = true;
              }}/node_modules node_modules
              chmod -R u+w node_modules
              node scripts/build.mjs
              runHook postBuild
            '';
            installPhase = ''
              mkdir -p $out
              cp -a dist $out/
            '';
          };

          # agent-ste compiles Gleam to JavaScript. The compiler reads its hex packages
          # from the cache, so the manifest's four tarballs are fetched here, named by
          # the manifest checksum.
          agentSteHex = pkgs.runCommand "agent-ste-hex-cache" { } ''
            mkdir -p $out
            cp ${pkgs.fetchurl {
              url = "https://repo.hex.pm/tarballs/gleam_json-3.1.0.tar";
              hash = "sha256-RP2qiEe+j8SMp6HAiXBr1UutzExFsjepku3fnyzbKDY=";
            }} $out/44FDAA8847BE8FC48CA7A1C089706BD54BADCC4C45B237A992EDDF9F2CDB2836.tar
            cp ${pkgs.fetchurl {
              url = "https://repo.hex.pm/tarballs/gleam_regexp-1.1.1.tar";
              hash = "sha256-nCFcbKhKWzW7k0qbYamjBux0MVO+KwQloNAy5HewYqk=";
            }} $out/9C215C6CA84A5B35BB934A9B61A9A306EC743153BE2B0425A0D032E477B062A9.tar
            cp ${pkgs.fetchurl {
              url = "https://repo.hex.pm/tarballs/gleam_stdlib-1.0.3.tar";
              hash = "sha256-H1Q6+6XTPaST5gh/TkxPINiZQRNDUSaGyYqKuyljzyI=";
            }} $out/1F543AFBA5D33DA493E6087F4E4C4F20D899411343512686C98A8ABB2963CF22.tar
            cp ${pkgs.fetchurl {
              url = "https://repo.hex.pm/tarballs/gleeunit-1.11.0.tar";
              hash = "sha256-7DGrp0JWrqUx7fgWmTHXdbuzhP7QqKG9xN2TVOPiGCY=";
            }} $out/EC31ABA74256AEA531EDF8169931D775BBB384FED0A8A1BDC4DD9354E3E21826.tar
          '';

          agentSte = pkgs.stdenvNoCC.mkDerivation {
            pname = "agent-ste-dist";
            version = "0";
            src = srcOf "vendor/ctotheameron/agent-ste";
            nativeBuildInputs = [ pkgs.gleam ];
            postPatch = ''
              patchShebangs scripts
            '';
            buildPhase = ''
              runHook preBuild
              export HOME=$TMPDIR/home
              mkdir -p $HOME/.cache/gleam/hex/hexpm/packages
              cp ${agentSteHex}/*.tar $HOME/.cache/gleam/hex/hexpm/packages/
              ./scripts/build-dist.sh
              runHook postBuild
            '';
            installPhase = ''
              mkdir -p $out
              cp -a dist $out/
            '';
          };

          # pi-lean-ctx stays in `extensions`, and its agent dir is writable (see
          # `writableExtensions` in pi-coding-agent.nix). Its factory reads a schema cache
          # beside its own config.json and starts an eager MCP connect only on a cache miss.
          # From the store tree that cache never persists, so every start would pay the full
          # ~3.3 s discovery. From a writable dir the cache is warm and the factory costs
          # about 4 ms. Its staging stays, so the tree keeps the host layout.

          # pi-lean-ctx bundles the MCP SDK into extensions/vendor at build time, and the
          # published package then carries no runtime npm dependency.
          piLeanCtx = pkgs.stdenvNoCC.mkDerivation {
            pname = "pi-lean-ctx-vendor-bundle";
            version = "0";
            src = srcOf "vendor/mattgmak/lean-ctx/packages/pi-lean-ctx";
            nativeBuildInputs = [ pkgs.nodejs ];
            buildPhase = ''
              runHook preBuild
              cp -a ${npmNodeModules {
                repo = "mattgmak/lean-ctx/packages/pi-lean-ctx";
                devDeps = true;
                # The build reads esbuild and the MCP SDK. The other dev entries pull
                # vite, whose esbuild range the lock satisfies only through the
                # manifest overrides, and an override cannot name a store file.
                keepDevDeps = [
                  "@modelcontextprotocol/sdk"
                  "esbuild"
                ];
                dropOverrides = true;
                # npm installs root peer deps, and the SDK peers resolve through the
                # dropped shrinkwrap.
                dropPeers = true;
                # The bundled shrinkwrap inside the dev SDK records seven nested
                # @earendil-works tarballs with no integrity, and the build never reads
                # them.
                dropPackages = name: lib.hasPrefix "node_modules/@earendil-works/pi-coding-agent/" name;
              }}/node_modules node_modules
              chmod -R u+w node_modules
              npm run build:vendor
              runHook postBuild
            '';
            installPhase = ''
              mkdir -p $out
              cp -a extensions/vendor $out/
            '';
          };

          # gentle-engram ships no dependencies of its own, but the host resolves its
          # bare imports through one shared vendor/node_modules, so the install runs here
          # the same way.
          engramDeps = pkgs.stdenvNoCC.mkDerivation {
            pname = "engram-pi-deps";
            version = "0";
            src = srcOf "vendor/Gentleman-Programming/engram/plugin/pi";
            nativeBuildInputs = [
              pkgs.nodejs
              pkgs.jq
            ];
            buildPhase = ''
              runHook preBuild
              jq '{name: "engram-pi-deps", private: true, dependencies: (.dependencies // {})}' \
                package.json > package.json.new
              mv package.json.new package.json
              npm install --omit=dev --no-package-lock --offline
              mkdir -p node_modules
              runHook postBuild
            '';
            installPhase = ''
              mkdir -p $out
              cp -a node_modules $out/
            '';
          };

          # pnpm workspace repos, same idea with one hash per lockfile. `hash` covers the
          # fetched pnpm store; a lockfile change makes the build stop and print the new
          # value at fetcherVersion 4, which pnpm 11 requires.
          pnpmDepRepos = [
            {
              repo = "gotgenes/pi-packages";
              hash = "sha256-0Hrtwjpu3uh9pV/dLYNpIUy3kaUeljk+vTQayjD/UAI=";
              workspaces = [
                "@gotgenes/pi-permission-system"
                "@gotgenes/pi-session-tools"
              ];
              packages = [
                "pi-permission-system"
                "pi-session-tools"
              ];
            }
          ];

          pnpmNodeModules =
            dep:
            pkgs.stdenvNoCC.mkDerivation {
              name = "${builtins.baseNameOf dep.repo}-node-modules";
              src = srcOf "vendor/${dep.repo}";
              pnpmWorkspaces = dep.workspaces;
              pnpmDeps = pkgs.fetchPnpmDeps {
                pname = builtins.baseNameOf dep.repo;
                version = "0";
                src = srcOf "vendor/${dep.repo}";
                fetcherVersion = 4;
                inherit (dep) hash workspaces;
                pnpmWorkspaces = dep.workspaces;
              };
              nativeBuildInputs = [
                pkgs.nodejs
                pkgs.pnpm
                pkgs.pnpmConfigHook
              ];
              dontBuild = true;
              # Workspace siblings stay uninstalled links to their registry copies.
              dontFixup = true;
              installPhase = ''
                mkdir -p $out/packages
                cp -a node_modules $out/
                ${lib.concatMapStrings (p: ''
                  mkdir -p $out/packages/${p}
                  cp -a packages/${p}/node_modules $out/packages/${p}/node_modules
                '') dep.packages}
              '';
            };

          rpivRoot = "stage/extensions/vendor/juicesharp/rpiv-mono";

          # The release binaries ask for /lib64/ld-linux-x86-64.so.2, which the sandbox does
          # not have. --set-interpreter only grows the file and leaves the AOT trailer valid;
          # --set-rpath rewrites it and the binary segfaults on start. libc comes from
          # LD_LIBRARY_PATH during the build, and the store loader resolves it once installed.
          libc = lib.getLib stdenv.cc.libc;
          loader = "${libc}/lib/ld-linux-x86-64.so.2";
          patchInterpreter = lib.optionalString stdenv.hostPlatform.isLinux ''
            patchelf --set-interpreter ${loader} app/pi
            patchelf --set-interpreter ${loader} unpack/runtime/bun
            export LD_LIBRARY_PATH=${libc}/lib
          '';

          # Native extension modules such as koffi dlopen against libstdc++, which the bun
          # binary does not carry and a bare shell does not export. macOS links libc++
          # from the system path, so only linux needs the flag.
          wrapperLdFlag = lib.optionalString stdenv.hostPlatform.isLinux
            "--prefix LD_LIBRARY_PATH : ${stdenv.cc.cc.lib}/lib";
        in
        stdenv.mkDerivation {
          pname = "pi-compiled";
          inherit version;

          appSrc = fetchurl {
            url = "${baseUrl}/pi-bolt-${attrs.variant}.tar.xz";
            hash = attrs.appHash;
          };
          runtimeSrc = fetchurl {
            url = "${baseUrl}/pi-bolt-runtime-${attrs.variant}.tar.gz";
            hash = attrs.runtimeHash;
          };
          kitSrc = fetchurl {
            url = "${baseUrl}/pi-bolt-kit-${attrs.variant}.tar.gz";
            hash = attrs.kitHash;
          };

          nativeBuildInputs = [
            gnutar
            gzip
            xz
            jq
            makeWrapper
            findutils
            coreutils
          ]
          ++ lib.optional stdenv.hostPlatform.isLinux patchelf;

          # AOT image: page-aligned sections appended to the executable with offsets in a
          # trailer, and the runtime re-opens its own file to verify it. Strip, sign and
          # rpath rewrites corrupt or break the trailer, so no fixup and no strip.
          dontFixup = true;
          dontStrip = true;
          dontPatchELF = true;

          # The compile writes $out itself.
          dontInstall = true;


          unpackPhase = ''
            runHook preUnpack
            mkdir -p unpack/app unpack/runtime unpack/kit
            tar -xf "$appSrc" -C unpack/app --strip-components=1
            tar -xf "$runtimeSrc" -C unpack/runtime --strip-components=1
            tar -xf "$kitSrc" -C unpack/kit --strip-components=1
            chmod -R u+w unpack
            runHook postUnpack
          '';

          # Stage the extension tree before the build: loader folder plus a real `vendor`
          # sibling. `pi compile` copies the whole extensions folder into
          # .pibolt-plugins/src/global/, so ../vendor/<owner>/<repo>/... resolves there. A
          # symlinked vendor does not survive the copy.
          postPatch = ''
            stage=$PWD/stage/extensions
            mkdir -p $stage/vendor
            ${lib.concatMapStrings (repo: ''
              mkdir -p $stage/vendor/${repo}
              # node_modules and .git stay out: they are gitignored, so they may be absent
              # from the store tree, and they are not needed. Any level counts: a nested one
              # holds pnpm links to install-time paths, and `pi compile` dies dereferencing
              # them.
              tar -cf - -C ${vendorRoot}/${repo} --exclude=node_modules --exclude=.git . \
                | tar -xf - -C $stage/vendor/${repo}
            '') vendorRepos}
            ${lib.concatMapStrings (s: ''
              mkdir -p $stage/vendor/${s.repo}/${s.subdir}
              tar -cf - -C ${vendorRoot}/${s.repo}/${s.subdir} --exclude=node_modules --exclude=.git . \
                | tar -xf - -C $stage/vendor/${s.repo}/${s.subdir}
            '') vendorSubdirs}
            chmod -R u+w $stage

            # pi-powerline-footer carries its palette as a home-manager symlink to a
            # generated store file that the sandbox does not have, and `pi compile`
            # dereferences every link it meets. Drop the link: the compiled copy falls back
            # to the vendor's own presets, while the on-disk extension keeps the symlink.
            find $stage -name theme.json -type l -delete

            ${lib.concatMapStrings (repo: ''
              cp -a ${npmNodeModules { inherit repo; }}/node_modules $stage/vendor/${repo}/node_modules
            '') npmDepRepos}
            ${lib.concatMapStrings (dep: ''
              cp -a ${pnpmNodeModules dep}/. $stage/vendor/${dep.repo}/
            '') pnpmDepRepos}

            # pi-agent-browser-native loads a built file, and its bundles leave the
            # runtime deps external.
            cp -a ${agentBrowserNative}/dist \
              $stage/vendor/fitchmultz/pi-agent-browser-native/
            cp -a ${npmNodeModules {
              repo = "fitchmultz/pi-agent-browser-native";
            }}/node_modules $stage/vendor/fitchmultz/pi-agent-browser-native/node_modules

            # agent-ste loads its compiled Gleam output from dist/.
            cp -a ${agentSte}/dist $stage/vendor/ctotheameron/agent-ste/

            # pi-lean-ctx loads its bundled MCP SDK from extensions/vendor. The staged dir
            # already exists, so copy the contents, not the dir itself.
            cp -a ${piLeanCtx}/vendor/. \
              $stage/vendor/mattgmak/lean-ctx/packages/pi-lean-ctx/extensions/vendor/

            # gentle-engram resolves its bare imports through vendor/node_modules.
            mkdir -p $stage/vendor/.engram-deps
            cp -a ${engramDeps}/node_modules $stage/vendor/.engram-deps/node_modules
            ln -sfn .engram-deps/node_modules $stage/vendor/node_modules

            # pi-interactive-subagents imports the pre-rename @sinclair/typebox name.
            # The kit carries the renamed `typebox` package, which exports the same
            # builders, so the patch points the three imports at it.
            (
              cd stage/extensions/vendor/mattgmak/pi-interactive-subagents
              patch -p1 --batch < ${./pi-bolt-compiled/pi-interactive-subagents-typebox.patch}
            )

            # Those two packages import their workspace siblings. The bundler reads the
            # copies under .pibolt-plugins, not the vendor tree, so only the kit's
            # node_modules is on its path.
            mkdir -p ${kitTree}/node_modules/@juicesharp
            cp -a ${rpivRoot}/packages/rpiv-config ${rpivRoot}/packages/rpiv-i18n \
              ${kitTree}/node_modules/@juicesharp/

            # The bundle entry needs a writable kit, so the build reads a copy.
            cp -a unpack/kit kit
            chmod -R u+w kit
            cp ${cursorSdkBundle}/pi-bolt-bundle.js kit/tree/packages/coding-agent/pi-bolt-bundle.js
            jq '.entries += ["./pi-bolt-bundle.js"]' kit/kit.json > kit.json.new
            mv kit.json.new kit/kit.json
          '';

          buildPhase = ''
            runHook preBuild

            # pi compile records the absolute extension paths in sources.json, and the run time
            # compares them against the paths it finds. Put them where they will live, so the
            # recorded root equals the run-time root and the fingerprint lookup hits.
            export HOME="$out/share/pibolt-home"
            mkdir -p "$HOME/.pi/agent/extensions" "$HOME/.bun"
            ${lib.concatMapStrings (name: ''
              cp -a ${extensionsDir}/${name} "$HOME/.pi/agent/extensions/${name}"
            '') extensions}
            # Git ignores the prebuilt bundle in the repo loader folder, so the flake source
            # lacks it. Ship the compiled bundle here. Both hosts then find it beside
            # index.ts, and the run-time fingerprint stays stable. cp -a keeps the source
            # read-only, so make the folder writable first.
            chmod u+w "$HOME/.pi/agent/extensions/pi-cursor-sdk"
            cp ${cursorSdkBundle}/pi-bolt-bundle.js \
              "$HOME/.pi/agent/extensions/pi-cursor-sdk/pi-bolt-bundle.js"
            cp -a stage/extensions/vendor "$HOME/.pi/agent/extensions/vendor"
            chmod -R u+w "$HOME"

            # The fingerprint uses Math.trunc(mtimeMs). Nix sets store mtimes to 1, so pin
            # every staged file to exactly @1 and both sides agree at 1000. GNU touch on
            # both platforms: BSD touch takes no `-d @1`.
            ${lib.getExe findutils} "$HOME" -exec ${lib.getExe' coreutils "touch"} -h -d @1 {} +

            # Writable copy of the app tree: pi compile fails with EACCES on temp cleanup
            # when the tree is read-only, and it writes beside the executable.
            cp -a unpack/app app
            chmod -R u+w app

            ${patchInterpreter}

            # PI_PACKAGE_DIR overrides the executable's own directory and wins over it, so
            # pin it to the copy. The wrapper sets PIBOLT_NPM and the compile path rejects
            # npm installs, so clear it.
            export PI_PACKAGE_DIR="$PWD/app"
            export PI_TELEMETRY=0
            unset PIBOLT_NPM
            # Default is 262144 bytes of bytecode; 1 MB passes the larger bundled modules.
            export BUN_JSC_maximumAOTCandidateBytecodeSize=1048576

            # --kit with --runtime is the offline pair. Missing either one makes compile
            # fetch SHA256SUMS and SHA256SUMS.sig from the release.
            ./app/pi compile \
              --out "$out/libexec/pi" \
              --kit "$PWD/kit" \
              --runtime "$PWD/unpack/runtime/bun"

            # darwin splits the image: a 37K `pi` launcher execs the real `pi-bin` beside
            # it, so the running app would be named `pi-bin`. Swap them as pi-bolt.nix
            # does: real app becomes `pi`, and the `pi-bin` symlink keeps the launcher's
            # sibling lookup resolving. linux ships one self-contained `pi`.
            if [ -e "$out/libexec/pi/pi-bin" ]; then
              mv "$out/libexec/pi/pi" "$out/libexec/pi/pi-launcher"
              mv "$out/libexec/pi/pi-bin" "$out/libexec/pi/pi"
              ln -s pi "$out/libexec/pi/pi-bin"
            fi

            # Default command. The AOT image re-opens its own file, and the runtime reads
            # package.json, theme/ and export-html/ from the package directory, so the
            # wrapper stays outside that directory and pins PI_PACKAGE_DIR to it.
            # PIBOLT_NPM keeps `pi update` from curl-installing over the store path.
            mkdir -p "$out/bin"
            makeWrapper "$out/libexec/pi/pi" "$out/bin/pi" \
              --argv0 pi \
              --set PIBOLT_NPM 1 \
              --set PI_TELEMETRY 0 \
              --set ENGRAM_URL http://127.0.0.1:7437 \
              --set PI_PACKAGE_DIR "$out/libexec/pi" \
              ${wrapperLdFlag}

            runHook postBuild
          '';

          doInstallCheck = stdenv.buildPlatform.canExecute stdenv.hostPlatform;
          installCheckPhase = ''
            runHook preInstallCheck
            "$out/libexec/pi/pi" --version
            "$out/bin/pi" --version
            runHook postInstallCheck
          '';

          passthru = {
            inherit extensions vendorRepos;
            experimental = true;
          };

          meta = with lib; {
            description = "Pi coding agent (Pi-Bolt fork) with extensions compiled in ahead of time (experimental)";
            homepage = "https://github.com/opensec-git/Pi-Bolt";
            license = licenses.mit;
            sourceProvenance = with sourceTypes; [ binaryNativeCode ];
            platforms = builtins.attrNames platformAttrs;
            mainProgram = "pi";
          };
        }
      ) { };
    in
    {
      packages.piCompiled = piCompiled;
    };
}
