{
  flake.homeModules.mac-mini-home = {
    home.sessionVariables = {
      UV_CACHE_DIR = "/Volumes/Kingston480GB/reloc/uv-cache";
      NODE_COMPILE_CACHE = "/Volumes/Kingston480GB/reloc/node-compile-cache";
      COREPACK_HOME = "/Volumes/Kingston480GB/reloc/corepack";
      PUPPETEER_CACHE_DIR = "/Volumes/Kingston480GB/reloc/puppeteer";
      # macOS sshd hands over no locale. Without UTF-8, tmux reads the client as
      # non-UTF-8 and draws every icon and separator as "_".
      LANG = "en_US.UTF-8";
      # Ghostty keeps xterm-ghostty only in the app bundle, so a remote ssh
      # client that arrives with that TERM fails in tmux. The empty list element
      # keeps the system terminfo directory in the search path.
      TERMINFO_DIRS = "/Applications/Ghostty.app/Contents/Resources/terminfo:";
    };
  };
}
