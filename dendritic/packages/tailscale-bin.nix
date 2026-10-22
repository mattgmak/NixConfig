{ inputs, ... }:
{
  perSystem =
    { system, ... }:
    let
      # Unoverlaid nixpkgs: the tailscaleBin overlay points at this derivation, so
      # building it from the overlaid pkgs would recurse back into the overlay.
      pkgs = import inputs.nixpkgs { inherit system; };
      tailscaleBin = pkgs.callPackage (
        {
          lib,
          stdenv,
          fetchurl,
          makeWrapper,
          iptables,
          nftables,
          iproute2,
          openresolv,
        }:

        # TODO: drop this package once nixpkgs ships tailscale 1.104.2 in the binary cache.
        let
          version = "1.104.2";
          srcs = {
            aarch64-linux = {
              url = "https://pkgs.tailscale.com/stable/tailscale_${version}_arm64.tgz";
              hash = "sha256-V3aqqQG17xkW5mvlu1S59IHNOZycKNsSOoyrYg76I3s=";
              dir = "tailscale_${version}_arm64";
            };
            x86_64-linux = {
              url = "https://pkgs.tailscale.com/stable/tailscale_${version}_amd64.tgz";
              hash = "sha256-US9hPtfQT8coL33FvXaqEFquKBaPu5NX63SevLwp8K4=";
              dir = "tailscale_${version}_amd64";
            };
          };
          src =
            srcs.${stdenv.hostPlatform.system}
              or (throw "tailscale ${version}: no upstream tarball for ${stdenv.hostPlatform.system}");

          # The tarball ships no license file.
          licenseFile = fetchurl {
            url = "https://raw.githubusercontent.com/tailscale/tailscale/v${version}/LICENSE";
            hash = "sha256-p8phhqeWOgpgdA9gR3YO7NegI06MOL1+Hgu8syS9pFs=";
          };
        in
        stdenv.mkDerivation {
          pname = "tailscale";
          inherit version;

          src = fetchurl {
            inherit (src) url hash;
          };

          # Both shipped ELF files are static ET_EXEC (Go, no PT_INTERP, no DT_NEEDED),
          # so no autoPatchelfHook is needed.
          dontStrip = true;
          dontPatchELF = true;

          nativeBuildInputs = [ makeWrapper ];

          sourceRoot = src.dir;

          installPhase = ''
            runHook preInstall
            install -Dm755 tailscale $out/bin/tailscale
            install -Dm755 tailscaled $out/bin/tailscaled
            install -Dm644 ${licenseFile} $out/share/licenses/tailscale/LICENSE
            install -Dm644 systemd/tailscaled.service $out/lib/systemd/system/tailscaled.service
            # systemd.packages pulls this unit in. Retarget it at the nix store.
            sed -i \
              -e "s#/usr/sbin#$out/bin#" \
              -e "/^EnvironmentFile/d" \
              $out/lib/systemd/system/tailscaled.service
            wrapProgram $out/bin/tailscaled \
              --prefix PATH : "${lib.makeBinPath [
                iptables
                nftables
                iproute2
              ]}:${openresolv}/sbin"
            runHook postInstall
          '';

          meta = {
            description = "Mesh VPN daemon, prebuilt upstream binary";
            homepage = "https://tailscale.com";
            license = lib.licenses.bsd3;
            mainProgram = "tailscale";
            sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
            platforms = builtins.attrNames srcs;
          };
        }
      ) { };
    in
    # Upstream ships no darwin tarball, so this stays a linux-only package.
    pkgs.lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
      packages.tailscaleBin = tailscaleBin;
    };
}
