{
  config,
  lib,
  ...
}:

let
  service = "open-seo";
  cfg = config.homelab.services.${service};
  homelab = config.homelab;
  open-seo-version = "v0.1.7";
  containerPort = 3001; # fixed app port inside the container (image EXPOSE/healthcheck)
in
{
  options.homelab.services.${service} = {
    enable = lib.mkEnableOption {
      description = "Enable ${service}";
    };
    user = lib.mkOption {
      default = "open-seo";
      type = lib.types.str;
      description = ''
        User account under which Open-SEO runs: the container's root user is
        mapped to this host user via a user namespace (--uidmap), since the
        image (node:22 based) builds its client/server bundle into /app on
        every environment change and therefore needs the in-container root.
      '';
    };
    uid = lib.mkOption {
      type = lib.types.int;
      default = 391;
      description = ''
        Static UID for the ${service} user. A fixed value is required because
        the container's user namespace mapping must be rendered at evaluation
        time. The default lies outside NixOS' dynamic system id range
        (400-999) and is unused in nixpkgs' ids.nix.
      '';
    };
    gid = lib.mkOption {
      type = lib.types.int;
      default = 391;
      description = "Static GID for the ${service} group, see `uid`.";
    };
    group = lib.mkOption {
      default = "open-seo";
      type = lib.types.str;
      description = ''
        Group under which Open-SEO runs.
      '';
    };
    createUser = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to create the user and group defined in `user` and `group` automatically as a system user.";
    };
    stateDir = lib.mkOption {
      type = lib.types.path;
      description = "Directory containing the persistent state data to back up";
      default = "/var/lib/${service}";
    };
    url = lib.mkOption {
      type = lib.types.str;
      default = "open-seo.${homelab.baseDomain}";
    };
    listenAddress = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
    };
    listenPort = lib.mkOption {
      type = lib.types.port;
      default = 4008;
    };
    secretEnvironmentFile = lib.mkOption {
      description = "File with secret environment variables, e.g. DATAFORSEO_API_KEY";
      type = lib.types.path;
      default = config.age.secrets.openSeoEnv.path;
      example = lib.literalExpression ''
        pkgs.writeText "openSeoEnv" '''
          DATAFORSEO_API_KEY=<base64 of "email:password">
        '''
      '';
    };
    homepage.name = lib.mkOption {
      type = lib.types.str;
      default = "Open-SEO";
    };
    homepage.description = lib.mkOption {
      type = lib.types.str;
      default = "SEO research and rank tracking";
    };
    homepage.icon = lib.mkOption {
      type = lib.types.str;
      # no dashboard-icons entry for Open-SEO yet, fall back to a Material Design icon
      default = "mdi-magnify";
    };
    homepage.category = lib.mkOption {
      type = lib.types.str;
      default = "Professional";
    };
    blackbox.targets = import ../../../../lib/options/blackboxTargets.nix {
      inherit lib;
      defaultTargets =
        let
          blackbox = import ../../../../lib/blackbox.nix { inherit lib; };
        in
        [
          (blackbox.mkHttpTarget "${service}" "${cfg.url}" "external")
        ];
    };
  };

  config = lib.mkIf cfg.enable {
    users.groups.${cfg.group} = lib.mkIf cfg.createUser {
      gid = cfg.gid;
    };
    users.users.${cfg.user} = lib.mkIf cfg.createUser {
      uid = cfg.uid;
      isSystemUser = true;
      description = "Runs ${service} (container root is mapped to this user)";
      group = cfg.group;
    };

    # The entrypoint (pnpm/vite build and preview output) logs without level
    # tags; without this, every stderr line of the container would show up as
    # level "err" in Loki
    homelab.services.loki.untaggedContainerLogUnits = [ "podman-${service}.service" ];

    # Ensure directories exists with correct permissions
    systemd.tmpfiles.rules = [
      "d ${cfg.stateDir}/data 0770 ${cfg.user} ${cfg.group} - -"
      "Z ${cfg.stateDir}/data 0770 ${cfg.user} ${cfg.group} - -"
    ];

    virtualisation = {
      podman.enable = true;
      oci-containers = {
        containers = {
          # see https://github.com/every-app/open-seo/blob/main/docs/SELF_HOSTING_DOCKER.md
          # Single self-contained container: state (local D1/SQLite) lives in
          # /app/.wrangler, there is no external database or cache.
          "${service}" = {
            image = "ghcr.io/every-app/open-seo:${open-seo-version}";
            autoStart = true;
            volumes = [
              "${cfg.stateDir}/data:/app/.wrangler"
            ];
            ports = [
              "${cfg.listenAddress}:${toString cfg.listenPort}:${toString containerPort}"
            ];
            environmentFiles = [ cfg.secretEnvironmentFile ];
            environment = {
              # === Required Settings
              # DATAFORSEO_API_KEY is set in secretEnvironmentFile
              # No built-in authentication: the app injects a local admin user.
              # Safe here because the Caddy vhost below is only reachable on
              # the private network; never expose this vhost publicly.
              AUTH_MODE = "local_noauth";
              # Vite preview host check: only requests with this Host header
              # are answered, which matches the reverse proxy below.
              ALLOWED_HOST = cfg.url;
              # wrangler runs the app in the local Cloudflare Workers runtime,
              # which only sees env vars passed through as bindings; this
              # forwards the container environment (DATAFORSEO_API_KEY,
              # AUTH_MODE, ...) into the Worker.
              CLOUDFLARE_INCLUDE_PROCESS_ENV = "true";

              # === Privacy Settings
              OPENSEO_TELEMETRY_DISABLED = "1";
              DO_NOT_TRACK = "1";

              # === Optional AI / Google Search Console Settings
              # OPENROUTER_API_KEY, GOOGLE_CLIENT_ID, GOOGLE_CLIENT_SECRET and
              # BETTER_AUTH_SECRET are set in secretEnvironmentFile if used
              # External URL for OAuth redirect URIs (Google Search Console):
              # the container itself speaks plain HTTP behind Caddy, so without
              # this the derived redirect_uri would be http:// and Google would
              # reject it with redirect_uri_mismatch.
              BETTER_AUTH_URL = "https://${cfg.url}";

              # === Developer Settings
              VITE_SHOW_DEVTOOLS = "false";
            };
            extraOptions = [
              # Run the container in a user namespace: the image expects to run
              # as root *inside* the container (build output and fingerprint are
              # written to /app), but that root is mapped to the unprivileged
              # open-seo user on the host (state dir ownership follows from
              # this). All other container ids map to an otherwise unused
              # sub-id range, disjoint from the range used by the Postiz
              # container.
              "--uidmap=0:${toString cfg.uid}:1"
              "--uidmap=1:200000:65535"
              "--gidmap=0:${toString cfg.gid}:1"
              "--gidmap=1:200000:65535"
            ];
          };
        };
      };
    };
    systemd.services."podman-${service}" = {
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
    };

    services.caddy.virtualHosts."${cfg.url}" = {
      useACMEHost = homelab.baseDomain;
      extraConfig = ''
        reverse_proxy http://${cfg.listenAddress}:${toString cfg.listenPort}
      '';
    };
  };
}
