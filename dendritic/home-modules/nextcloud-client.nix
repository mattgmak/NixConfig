{
  flake.homeModules.nextcloudClient = {
    services.nextcloud-client = {
      enable = true;
      startInBackground = true;
    };
  };
}
