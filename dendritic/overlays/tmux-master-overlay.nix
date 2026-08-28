# tmux master — popup/floating redraw flicker fixes (#5336, #5398, #5350).
# Pin rev; bump when chasing upstream redraw fixes.
{ ... }:
let
  rev = "267746603a4ff25baad62e3477b126411e49b52f";
  version = "3.8-pre";
  srcHash = "sha256-YFIti1JYm6a4YBntNDE8zf+kQs3zx2s44SjRSzHYw+A=";
in
{
  flake.tmuxMasterOverlay =
    final: prev:
    {
      tmux = prev.tmux.overrideAttrs (old: {
        inherit version;
        src = prev.fetchFromGitHub {
          owner = "tmux";
          repo = "tmux";
          inherit rev;
          hash = srcHash;
        };
        # master configure.ac requires explicit jemalloc choice on Darwin
        buildInputs =
          (old.buildInputs or [ ])
          ++ prev.lib.optionals prev.stdenv.hostPlatform.isDarwin [ prev.jemalloc ];
        configureFlags =
          (old.configureFlags or [ ])
          ++ prev.lib.optionals prev.stdenv.hostPlatform.isDarwin [ "--enable-jemalloc" ];
        # master reports e.g. tmux next-3.8, not our version string
        doInstallCheck = false;
        meta = old.meta // {
          description = "Terminal multiplexer (tmux/tmux master @ ${rev})";
        };
      });
    };
}
