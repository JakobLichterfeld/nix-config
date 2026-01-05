{
  config,
  lib,
  pkgs,
  ...
}:
let
  service = "languagetool";
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
    listenAddress = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
    };
    listenPort = lib.mkOption {
      type = lib.types.port;
      default = 8084;
    };
    homepage.name = lib.mkOption {
      type = lib.types.str;
      default = "LanguageTool";
    };
    homepage.description = lib.mkOption {
      type = lib.types.str;
      default = "A multilingual spelling, style, and grammar checker that helps correct or paraphrase texts.";
    };
    homepage.icon = lib.mkOption {
      type = lib.types.str;
      default = "https://upload.wikimedia.org/wikipedia/commons/4/45/LanguageTool_Logo.svg";
    };
    homepage.category = lib.mkOption {
      type = lib.types.str;
      default = "Services";
    };
    blackbox.targets = import ../../../lib/options/blackboxTargets.nix {
      inherit lib;
      defaultTargets =
        let
          blackbox = import ../../../lib/blackbox.nix { inherit lib; };
        in
        [
          (blackbox.mkHttpTarget "${service}" "${cfg.url}/healthz" "external")
        ];
    };
  };
  config = lib.mkIf cfg.enable {
    services.languagetool = {
      enable = true;
      # allowOrigin = ""; # https://${cfg.url} is enabled by default
      port = cfg.listenPort;
      public = false;
      settings.cacheSize = 1000; # Number of sentences cached.
    };

    services.caddy.virtualHosts."${cfg.url}" = {
      useACMEHost = homelab.baseDomain;
      extraConfig = ''
        # Health check endpoint for blackbox monitoring
        handle /healthz {
          respond "OK" 200
        }

        handle /v2* {
          reverse_proxy http://${cfg.listenAddress}:${toString config.services.languagetool.port}
        }

        handle {
          header Content-Type "text/html"
          respond <<EOF
            <!DOCTYPE html>
            <html>
            <head>
              <title>LanguageTool</title>
              <style>
                body { font-family: sans-serif; display: flex; justify-content: center; align-items: center; height: 100vh; background-color: #121212; color: #e0e0e0; }
                .container { text-align: center; padding: 2em; border: 1px solid #333; border-radius: 8px; background-color: #1e1e1e; }
                h1 { color: #ffffff; }
                a { color: #8ab4f8; }
                code { background-color: #333; padding: 0.2em 0.4em; border-radius: 4px; color: #e0e0e0; }
              </style>
            </head>
            <body>
              <div class="container">
                <h1>LanguageTool Server</h1>
                <p>To use this LanguageTool server, install <a href="https://languagetool.org/de/services#browsers">the official browser extension</a> and set the server URL in the advanced settings to:</p>
                <p><code>https://${cfg.url}/v2</code></p>
              </div>
            </body>
            </html>
          EOF
        }
      '';
    };
  };
}
