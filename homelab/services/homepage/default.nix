{
  config,
  lib,
  ...
}:
let
  service = "homepage-dashboard";
  cfg = config.homelab.services.homepage;
  homelab = config.homelab;
  bookmarks = import ./bookmarks.nix;
in
{
  options.homelab.services.homepage = {
    enable = lib.mkEnableOption {
      description = "Enable ${service}";
    };

    url = lib.mkOption {
      type = lib.types.str;
      default = "${homelab.baseDomain}";
    };

    homepageCategories = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        # "Arr"
        # "Downloads"
        # "Media"
        # "Network"
        "Tesla"
        "Services"
        "Smart Home"
        "Mobile"
        "Other Devices"
        # "System"
        # "Health Checks"
        "External Services"
      ];
      description = "Categories to group services on the homepage.";
    };

    extraServices = lib.mkOption {
      default = [ ];
      type = lib.types.listOf (
        lib.types.submodule {
          options = {
            category = lib.mkOption { type = lib.types.str; };
            name = lib.mkOption { type = lib.types.str; };
            description = lib.mkOption { type = lib.types.str; };
            href = lib.mkOption { type = lib.types.str; };
            siteMonitor = lib.mkOption { type = lib.types.str; };
            icon = lib.mkOption { type = lib.types.str; };
          };
        }
      );
      description = "A list of extra services to show on the homepage.";
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

    bookmarks = lib.mkOption {
      type = lib.types.listOf (
        lib.types.attrsOf (lib.types.listOf (lib.types.attrsOf (lib.types.listOf lib.types.attrs)))
      );
      default = import ./bookmarks.nix;
      description = "Bookmarks to show on the homepage.";
      example = [
        {
          "NixOS" = [
            {
              name = "NixOS";
              href = "https://nixos.org";
              icon = "si-nixos";
            }
          ];
        }
        {
          "GitHub" = [
            {
              name = "GitHub";
              href = "https://github.com";
              icon = "github";
            }
          ];
        }
      ];
    };

    blackbox.targets = import ../../../lib/options/blackboxTargets.nix {
      inherit lib;
      defaultTargets =
        let
          blackbox = import ../../../lib/blackbox.nix { inherit lib; };
        in
        [
          (blackbox.mkHttpTarget "${service}" "http://127.0.0.1:${
            toString config.services.${service}.listenPort
          }" "internal")
          (blackbox.mkHttpTarget "${service}" "${cfg.url}" "external")
        ];
    };
  };
  config = lib.mkIf cfg.enable {
    services.glances.enable = true;
    services.${service} = {
      enable = true;
      allowedHosts = "127.0.0.1,::1,localhost,${homelab.baseDomain}";

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
              columns = 4;
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
          # {
          #   Network = {
          #     header = true;
          #     icon = "mdi-lan";
          #     style = "column";
          #     showStats = true;
          #   };
          # }
          {
            Tesla = {
              header = true;
              icon = "si-tesla";
              style = "column";
              showStats = true;
            };
          }
          {
            Services = {
              header = true;
              icon = "mdi-tools";
              style = "column";
            };
          }
          {
            "Smart Home" = {
              header = true;
              icon = "mdi-home-automation";
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
            "Other Devices" = {
              header = true;
              icon = "mdi-devices";
              style = "column";
              initiallyCollapsed = true;
            };
          }

          # {
          #   System = {
          #     header = true;
          #     icon = "mdi-desktop-classic";
          #     style = "column";
          #     showStats = true;
          #   };
          # }
          # {
          #   "Health Checks" = {
          #     header = true;
          #     icon = "mdi-check-network-outline";
          #     style = "column";
          #   };
          # }
          {
            "External Services" = {
              header = true;
              icon = "mdi-open-in-new";
              style = "column";
              initiallyCollapsed = true;
            };
          }
        ];
      };
      services =
        let
          homepageCategories = cfg.homepageCategories;
          hl = config.homelab.services;
          homepageServices =
            x:
            (lib.attrsets.filterAttrs (
              name: value: value ? homepage && value.homepage.category == x
            ) homelab.services);

          extraServicesByCategory =
            cat:
            lib.lists.forEach (lib.lists.filter (l: l.category == cat) cfg.extraServices) (l: {
              "${l.name}" = {
                icon = l.icon;
                description = l.description;
                href = l.href;
                siteMonitor = l.siteMonitor;
              };
            });
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
              })
            ++ extraServicesByCategory cat;
        })
        ++ lib.optional (cfg.misc != [ ]) { Misc = cfg.misc; }
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
                # {
                #   "Network 2" = {
                #     widget = {
                #       type = "glances";
                #       url = "http://localhost:${port}";
                #       metric = "network:enp2s0";
                #       chart = false;
                #       version = 4;
                #     };
                #   };
                # }
              ];
          }
        ];

      bookmarks = cfg.bookmarks;
    };
    services.caddy.virtualHosts."${cfg.url}" = {
      useACMEHost = homelab.baseDomain;
      extraConfig = ''
        reverse_proxy http://127.0.0.1:${toString config.services.${service}.listenPort}
      '';
    };
  };
}
