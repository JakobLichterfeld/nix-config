{ config, lib, ... }:
let
  service = "stirling-pdf";
  cfg = config.homelab.services.${service};
  homelab = config.homelab;
in
{
  options.homelab.services.${service} = {
    enable = lib.mkEnableOption {
      description = "Enable ${service}";
    };
    url = lib.mkOption {
      type = lib.types.str;
      default = "${service}.${homelab.baseDomain}";
    };
    listenPort = lib.mkOption {
      type = lib.types.int;
      default = 8081;
    };
    homepage.name = lib.mkOption {
      type = lib.types.str;
      default = "Stirling PDF";
    };
    homepage.description = lib.mkOption {
      type = lib.types.str;
      default = "Perform various operations on PDF files";
    };
    homepage.icon = lib.mkOption {
      type = lib.types.str;
      default = "stirling-pdf.svg";
    };
    homepage.category = lib.mkOption {
      type = lib.types.str;
      default = "Services";
    };
  };
  config = lib.mkIf cfg.enable {
    services.${service} = {
      enable = true;
      environment = {
        SERVER_PORT = "${toString cfg.listenPort}";
        SYSTEM_SHOWUPDATE = "false";
        SYSTEM_ENABLEANALYTICS = "false";
        SYSTEM_DEFAULTLOCALE = "de-DE";
        INSTALL_BOOK_AND_ADVANCED_HTML_OPS = "true";

      };
      environmentFiles = [ ];
    };
    services.caddy.virtualHosts."${cfg.url}" = {
      useACMEHost = homelab.baseDomain;
      extraConfig = ''
        reverse_proxy http://127.0.0.1:${toString cfg.listenPort}
      '';
    };
  };

}
