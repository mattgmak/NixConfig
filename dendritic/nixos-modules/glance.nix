{ self, ... }:
{
  flake.nixosModules.glance =
    {
      config,
      lib,
      pkgs-for-homelab,
      ...
    }:
    let
      immichPort = config.services.immich.port;
    in
    {
      services.glance = {
        enable = true;
        package = pkgs-for-homelab.glance;
        openFirewall = false;
        environmentFile = lib.mkIf config.services.glance.enable config.age.secrets.glance-env.path;
        settings = {
          server = {
            host = "0.0.0.0";
            port = 8080;
          };
          pages = [
            {
              name = "Dashboard";
              columns = [
                {
                  size = "full";
                  widgets = [
                    {
                      type = "server-stats";
                      servers = [
                        {
                          type = "local";
                          name = self.constants.serverName;
                          mountpoints = {
                            "/" = {
                              name = "Root";
                            };
                            "/mnt/2TBSeagateHDD" = {
                              name = "2TB HDD";
                            };
                          };
                        }
                      ];
                    }
                    {
                      type = "dns-stats";
                      service = "pihole-v6";
                      url = "http://finite.dab-octatonic.ts.net";
                      allow-insecure = true;
                      username = "admin";
                      password = "\${PIHOLE_PASSWORD}";
                    }
                    {
                      type = "docker-containers";
                      hide-by-default = false;
                    }
                    {
                      type = "custom-api";
                      title = "Immich stats";
                      cache = "1d";
                      url = "http://localhost:${toString immichPort}/api/server/statistics";
                      headers = {
                        "x-api-key" = "\${IMMICH_API_KEY}";
                        Accept = "application/json";
                      };
                      template = ''
                        <div class="flex justify-between text-center">
                          <div>
                            <div class="color-highlight size-h3">{{ .JSON.Int "photos" | formatNumber }}</div>
                            <div class="size-h6">PHOTOS</div>
                          </div>
                          <div>
                            <div class="color-highlight size-h3">{{ .JSON.Int "videos" | formatNumber }}</div>
                            <div class="size-h6">VIDEOS</div>
                          </div>
                          <div>
                            <div class="color-highlight size-h3">{{ div (.JSON.Int "usage" | toFloat) 1073741824 | toInt | formatNumber }}GB</div>
                            <div class="size-h6">USAGE</div>
                          </div>
                        </div>
                      '';
                    }
                  ];
                }
              ];
            }
          ];
        };
      };

      # Allow Glance to access Docker socket for docker-containers widget
      systemd.services.glance.serviceConfig.SupplementaryGroups = [ "docker" ];

      # systemd reads EnvironmentFile as root and passes vars into the service (DynamicUser-safe)
      age.secrets.glance-env = lib.mkIf config.services.glance.enable {
        file = ../../secrets/glance-env.age;
        mode = "0400";
      };

    };
}
