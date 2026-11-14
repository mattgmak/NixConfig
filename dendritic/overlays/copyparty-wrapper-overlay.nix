# copyparty makeWrapperArgs fix — upstream 9001/copyparty@1f8ebd5 passes
# makeWrapperArgs as the string "--prefix PATH : <paths>". The nixpkgs
# 2026-11-11 stdenv normalizes that argument with lib.toList, so the string
# becomes one list element. makeShellWrapper then rejects it:
#   Builder called die: makeWrapper doesn't understand the arg
#   --prefix PATH : /nix/store/...-util-linux-...-bin/bin:...
# The nixpkgs 2026-08-13 stdenv keeps the string form, so only the homelab
# channel breaks. Pass the four arguments explicitly.
{ ... }:
{
  flake.copypartyWrapperOverlay =
    final: prev:
    {
      copyparty = prev.copyparty.overrideAttrs (_: {
        makeWrapperArgs = [
          "--prefix"
          "PATH"
          ":"
          (final.lib.makeBinPath [ final.util-linux final.ffmpeg-full ])
        ];
      });
    };
}
