{
  config,
  lib,
  pkgs,
  ...
}:
let
  service = "pairdrop";
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
      type = lib.types.port;
      default = 3020;
    };
    homepage.name = lib.mkOption {
      type = lib.types.str;
      default = "PairDrop";
    };
    homepage.description = lib.mkOption {
      type = lib.types.str;
      default = "Transfer Files Cross-Platform.";
    };
    homepage.icon = lib.mkOption {
      type = lib.types.str;
      default = "https://github.com/schlagmichdoch/PairDrop/raw/master/public/images/android-chrome-512x512.png";
    };
    homepage.category = lib.mkOption {
      type = lib.types.str;
      default = "Services";
    };
  };
  config = lib.mkIf cfg.enable {
    services.pairdrop = {
      enable = true;
      package = pkgs.pairdrop;
      port = cfg.listenPort;
      environment = {
        # see https://github.com/schlagmichdoch/PairDrop/blob/master/docs/host-your-own.md#environment-variables
        DEBUG_MODE = false;
        WS_FALLBACK = true; # Websocket Fallback (for VPN)

        # Specify Signaling Server
        # E.g. host your own client files under pairdrop.your-domain.com but use the official
        # signaling server under pairdrop.net This way devices connecting to pairdrop.your-domain.com
        # and pairdrop.net can discover each other.
        # SIGNALING_SERVER = "pairdrop.net"; # not usable together with WS_FALLBACK = true;

        # IPV6_LOCALIZE = 4;
        # RATE_LIMIT = 1;

        # Customizable buttons for the About PairDrop page
        TWITTER_BUTTON_ACTIVE = false;
        MASTODON_BUTTON_ACTIVE = false;
        DONATION_BUTTON_ACTIVE = false;
        BLUESKY_BUTTON_ACTIVE = false;
        CUSTOM_BUTTON_ACTIVE = false;
        # CUSTOM_BUTTON_LINK = "https://";
        # CUSTOM_BUTTON_TITLE = "";
        PRIVACYPOLICY_BUTTON_ACTIVE = false;
      };
    };

    services.caddy.virtualHosts."${cfg.url}" = {
      useACMEHost = homelab.baseDomain;
      extraConfig = ''
        reverse_proxy http://127.0.0.1:${toString config.services.pairdrop.port}
      '';
    };
  };
}
