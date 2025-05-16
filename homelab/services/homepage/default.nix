{
  config,
  lib,
  ...
}:
let
  service = "homepage-dashboard";
  cfg = config.homelab.services.homepage;
  homelab = config.homelab;
in
{
  options.homelab.services.homepage = {
    enable = lib.mkEnableOption {
      description = "Enable ${service}";
    };
    misc = lib.mkOption {
      default = [ ];
      type = lib.types.listOf (
        lib.types.attrsOf (
          lib.types.submodule {
            options = {
              description = lib.mkOption {
                type = lib.types.str;
              };
              href = lib.mkOption {
                type = lib.types.str;
              };
              siteMonitor = lib.mkOption {
                type = lib.types.str;
              };
              icon = lib.mkOption {
                type = lib.types.str;
              };
            };
          }
        )
      );
    };
  };
  config = lib.mkIf cfg.enable {
    services.glances.enable = true;
    services.${service} = {
      enable = true;
      customCSS = ''
        body, html {
          font-family: SF Pro Display, Helvetica, Arial, sans-serif !important;
        }
        .font-medium {
          font-weight: 700 !important;
        }
        .font-light {
          font-weight: 500 !important;
        }
        .font-thin {
          font-weight: 400 !important;
        }
        #information-widgets {
          padding-left: 1.5rem;
          padding-right: 1.5rem;
        }
        div#footer {
          display: none;
        }
        .services-group.basis-full.flex-1.px-1.-my-1 {
          padding-bottom: 3rem;
        };
      '';
      settings = {
        theme = "dark";
        language = "de";
        color = "stone";
        headerStyle = "clean";
        statusStyle = "dot";
        hideVersion = "true";
        disableUpdateCheck = "true";

        layout = [
          {
            Glances = {
              header = false;
              style = "row";
              columns = 5;
            };
          }
          # {
          #   Arr = {
          #     header = true;
          #     style = "column";
          #   };
          # }
          # {
          #   Downloads = {
          #     header = true;
          #     style = "column";
          #   };
          # }
          # {
          #   Media = {
          #     header = true;
          #     style = "column";
          #   };
          # }
          {
            Network = {
              header = true;
              icon = "mdi-lan";
              style = "column";
              showStats = true;
            };
          }
          {
            Tesla = {
              header = true;
              icon = "si-tesla";
              style = "column";
              showStats = true;
            };
          }
          {
            "Other Devices" = {
              header = true;
              icon = "mdi-devices";
              style = "column";
            };
          }
          {
            Mobile = {
              header = true;
              icon = "si-oneplus";
              style = "column";
            };
          }
          {
            Services = {
              header = true;
              style = "column";
            };
          }
          {
            System = {
              header = true;
              icon = "mdi-desktop-classic";
              style = "column";
              showStats = true;
            };
          }
          {
            "Health Checks" = {
              header = true;
              icon = "https://healthchecks.io/static/img/logo.svg";
              style = "column";
            };
          }
          {
            "External Services" = {
              header = true;
              icon = "mdi-open-in-new";
              style = "column";
            };
          }
        ];
      };
      services =
        let
          homepageCategories = [
            # "Arr"
            # "Media"
            # "Downloads"
            "Network"
            "Tesla"
            "Other Devices"
            "Mobile"
            "Services"
            "System"
            "Health Checks"
            "External Services"
            # "Smart Home"
          ];
          hl = config.homelab.services;
          homepageServices =
            x:
            (lib.attrsets.filterAttrs (
              name: value: value ? homepage && value.homepage.category == x
            ) homelab.services);
        in
        lib.lists.forEach homepageCategories (cat: {
          "${cat}" =
            lib.lists.forEach (lib.attrsets.mapAttrsToList (name: value: name) (homepageServices "${cat}"))
              (x: {
                "${hl.${x}.homepage.name}" = {
                  icon = hl.${x}.homepage.icon;
                  description = hl.${x}.homepage.description;
                  href = "https://${hl.${x}.url}";
                  siteMonitor = "https://${hl.${x}.url}";
                };
              });
        })
        ++ [ { Misc = cfg.misc; } ]
        ++ [
          {
            Glances =
              let
                port = toString config.services.glances.port;
              in
              [
                {
                  Info = {
                    widget = {
                      type = "glances";
                      url = "http://localhost:${port}";
                      metric = "info";
                      chart = false;
                      version = 4;
                    };
                  };
                }
                {
                  "CPU Temp" = {
                    widget = {
                      type = "glances";
                      url = "http://localhost:${port}";
                      metric = "sensor:Package id 0";
                      chart = false;
                      version = 4;
                    };
                  };
                }
                {
                  Processes = {
                    widget = {
                      type = "glances";
                      url = "http://localhost:${port}";
                      metric = "process";
                      chart = false;
                      version = 4;
                    };
                  };
                }
                {
                  Network = {
                    widget = {
                      type = "glances";
                      url = "http://localhost:${port}";
                      metric = "network:enp1s0";
                      chart = false;
                      version = 4;
                    };
                  };
                }
                {
                  "Network 2" = {
                    widget = {
                      type = "glances";
                      url = "http://localhost:${port}";
                      metric = "network:enp2s0";
                      chart = false;
                      version = 4;
                    };
                  };
                }
              ];
          }
        ];

      bookmarks = [
        {
          "External Utilities" = [
            {
              "Google Notizen" = [
                {
                  abbr = "gk";
                  href = "https://keep.google.com/";
                  icon = "google-keep";
                }
              ];
            }
            {
              "Public IP" = [
                {
                  abbr = "IP";
                  description = "Check public IP and associated data";
                  icon = "https://www.whatismyip.com/images/What-Is-My-IP.webp";
                  href = "https://www.whatismyip.com/";
                }
              ];
            }
            {
              "Who Is Lookup" = [
                {
                  abbr = "WIs";
                  description = "Check ICAN info for a given IP address or domain";
                  icon = "https://images.g2crowd.com/uploads/product/image/large_detail/large_detail_5765bb06f84bd8aa701f4f68a3ad3711/domaintools.png";
                  href = "https://whois.domaintools.com/";
                }
              ];
            }
            {
              "Speed Test" = [
                {
                  abbr = "ST";
                  description = "Upload + download speeds and latency";
                  icon = "mdi-speedometer";
                  href = "https://speed.cloudflare.com/";
                }
              ];

            }
          ];
        }
        {
          "Development" = [
            {
              "GitHub" = [
                {
                  abbr = "GH";
                  description = "GitHub";
                  icon = "github";
                  href = "https://github.com/JakobLichterfeld";
                }
              ];
            }
            {
              "GitLab" = [
                {
                  abbr = "GL";
                  description = "GitLab";
                  icon = "gitlab";
                  href = "https://gitlab.com/GhostReader";
                }
              ];
            }
          ];
        }

      ];
    };
    services.caddy.virtualHosts."${homelab.baseDomain}" = {
      useACMEHost = homelab.baseDomain;
      extraConfig = ''
        reverse_proxy http://127.0.0.1:${toString config.services.${service}.listenPort}
      '';
    };
  };
}
