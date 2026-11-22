{
  flake.homeModules.vesktop = { ... }: {
    # Vesktop rewrites settings.json at runtime, so only the theme CSS is managed.
    # force replaces the copy Vesktop downloaded into ~/.config/vesktop/themes.
    home.file.".config/vesktop/themes/system24.theme.css" = {
      source = ./system24.theme.css;
      force = true;
    };
  };
}
