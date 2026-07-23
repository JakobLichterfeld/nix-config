{
  config,
  lib,
  pkgs,
  ...
}:

let
  service = "postiz";
  cfg = config.homelab.services.${service};
  homelab = config.homelab;
  postiz-version = "v2.21.10";
  podmanBridgeIp = "10.88.0.1"; # gateway of podman's default network, reachable from containers
in
{
  options.homelab.services.${service} = {
    enable = lib.mkEnableOption {
      description = "Enable ${service}";
    };
    user = lib.mkOption {
      default = "postiz";
      type = lib.types.str;
      description = ''
        User account under which Postiz runs: the container's root user is
        mapped to this host user via a user namespace (--uidmap), since the
        image's embedded nginx cannot run under an arbitrary non-root UID.
      '';
    };
    uid = lib.mkOption {
      type = lib.types.int;
      default = 390;
      description = ''
        Static UID for the ${service} user. A fixed value is required because
        the container's user namespace mapping must be rendered at evaluation
        time. The default lies outside NixOS' dynamic system id range
        (400-999) and is unused in nixpkgs' ids.nix.
      '';
    };
    gid = lib.mkOption {
      type = lib.types.int;
      default = 390;
      description = "Static GID for the ${service} group, see `uid`.";
    };
    group = lib.mkOption {
      default = "postiz";
      type = lib.types.str;
      description = ''
        Group under which Postiz runs.
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
    uploadDir = lib.mkOption {
      type = lib.types.path;
      description = "Upload Directory for Postiz.";
      default = "${homelab.mounts.merged}/media/postiz-upload";
    };
    # backup.additionalPathsToBackup = import ../../../../lib/options/backupAdditionalPathsToBackup.nix {
    #   inherit lib;
    #   additionalPathsToBackup = [ cfg.uploadDir];
    # };
    url = lib.mkOption {
      type = lib.types.str;
      default = "postiz.${homelab.baseDomain}";
    };
    listenAddress = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
    };
    listenPort = lib.mkOption {
      type = lib.types.port;
      default = 4007;
    };
    temporal = {
      listenPort = lib.mkOption {
        type = lib.types.port;
        default = 7233;
        description = "gRPC port of the Temporal frontend the Postiz container connects to.";
      };
    };
    secretEnvironmentFile = lib.mkOption {
      description = "File with secret environment variables, e.g. JWT_SECRET";
      type = lib.types.path;
      default = config.age.secrets.postizEnv.path;
      example = lib.literalExpression ''
        pkgs.writeText "postizEnv" '''
          JWT_SECRET=<secret>
        '''
      '';
    };
    homepage.name = lib.mkOption {
      type = lib.types.str;
      default = "Postiz";
    };
    homepage.description = lib.mkOption {
      type = lib.types.str;
      default = "Social media scheduling tool.";
    };
    homepage.icon = lib.mkOption {
      type = lib.types.str;
      default = "postiz.svg";
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

  config =
    let
      postizPostgresDb = "${cfg.user}"; # as ensureDBOwnership grants the user ownership to a database with the same name only
      pgPort = config.services.postgresql.settings.port;

      temporalUser = config.services.temporal.user;
      temporalDb = temporalUser; # as ensureDBOwnership grants the user ownership to a database with the same name only
      temporalVisibilityDb = "temporal_visibility";
      temporalPort = cfg.temporal.listenPort;
      # pkgs.temporal ships the SQL migrations alongside the binaries
      temporalSchemaDir = "${config.services.temporal.package}/share/schema/postgresql/v12";
      temporalSqlTool = lib.concatStringsSep " " [
        "temporal-sql-tool"
        "--plugin postgres12"
        "--ep 127.0.0.1"
        "-p ${toString pgPort}"
        "-u ${temporalUser}"
      ];

      redisSocketDir = "/run/redis-${service}";
      redisSocket = "${redisSocketDir}/redis.sock";
    in
    lib.mkIf cfg.enable {
      users.groups.${cfg.group} = lib.mkIf cfg.createUser {
        gid = cfg.gid;
      };
      users.users.${cfg.user} = lib.mkIf cfg.createUser {
        uid = cfg.uid;
        isSystemUser = true;
        description = "Runs ${service} (container root is mapped to this user)";
        group = cfg.group;
      };

      # Postiz logs without level tags; without this, every stderr line of the
      # container (e.g. the pnpm/prisma startup output) would show up as level
      # "err" in Loki
      homelab.services.loki.untaggedContainerLogUnits = [ "podman-postiz-app.service" ];

      # Ensure directories exists with correct permissions
      systemd.tmpfiles.rules = [
        "d ${cfg.stateDir}/config 0770 ${cfg.user} ${cfg.group} - -"
        "Z ${cfg.stateDir}/config 0770 ${cfg.user} ${cfg.group} - -"
        "d ${cfg.uploadDir} 0770 ${cfg.user} media - -"
        "Z ${cfg.uploadDir} 0770 ${cfg.user} media - -"
      ];

      services.postgresql = {
        enable = true;
        ensureDatabases = [
          postizPostgresDb
          temporalDb
        ];
        ensureUsers = [
          {
            name = cfg.user;
            ensureDBOwnership = true;
          }
          {
            name = temporalUser;
            ensureDBOwnership = true;
          }
        ];
        # Inserted above the NixOS defaults (peer for local, password for
        # TCP): Temporal's systemd hardening (RestrictAddressFamilies without
        # AF_UNIX) forces TCP loopback; trust is scoped to its own databases.
        # Postiz itself needs no extra rule: its container root is mapped to
        # the postiz user, so the default local peer auth applies.
        authentication = ''
          host ${temporalDb},${temporalVisibilityDb} ${temporalUser} 127.0.0.1/32 trust
          host ${temporalDb},${temporalVisibilityDb} ${temporalUser} ::1/128 trust
        '';
      };

      services.redis.servers.${service} = {
        enable = true;
        group = cfg.group; # grants the mapped container user access to the socket below
        port = 0; # only UNIX socket
        unixSocket = redisSocket;
        unixSocketPerm = 770;
      };

      services.temporal = {
        enable = true;
        # Real temporal-server.yaml schema, see
        # https://docs.temporal.io/references/configuration
        # (the DB/POSTGRES_*/ES_* variables from the docker-compose reference
        # are entrypoint settings of the temporalio/auto-setup image and have
        # no meaning here). Visibility lives in PostgreSQL, so no
        # Elasticsearch is needed.
        settings = {
          log = {
            stdout = true;
            level = "info";
          };
          persistence = {
            defaultStore = "default";
            visibilityStore = "visibility";
            numHistoryShards = 4; # immutable after first start
            datastores = {
              default = {
                sql = {
                  pluginName = "postgres12";
                  databaseName = temporalDb;
                  connectAddr = "127.0.0.1:${toString pgPort}";
                  connectProtocol = "tcp";
                  user = temporalUser;
                  password = "";
                  maxConns = 20;
                  maxIdleConns = 20;
                  maxConnLifetime = "1h";
                };
              };
              visibility = {
                sql = {
                  pluginName = "postgres12";
                  databaseName = temporalVisibilityDb;
                  connectAddr = "127.0.0.1:${toString pgPort}";
                  connectProtocol = "tcp";
                  user = temporalUser;
                  password = "";
                  maxConns = 10;
                  maxIdleConns = 10;
                  maxConnLifetime = "1h";
                };
              };
            };
          };
          global.membership = {
            maxJoinDuration = "30s";
            broadcastAddress = "127.0.0.1";
          };
          services = {
            # Only the frontend binds on all interfaces: the Postiz container
            # reaches it through the podman bridge, the firewall below keeps
            # everything else out. The internal services stay on loopback.
            frontend.rpc = {
              grpcPort = temporalPort;
              membershipPort = 6933;
              bindOnIP = "0.0.0.0";
              httpPort = 7243;
            };
            history.rpc = {
              grpcPort = 7234;
              membershipPort = 6934;
              bindOnLocalHost = true;
            };
            matching.rpc = {
              grpcPort = 7235;
              membershipPort = 6935;
              bindOnLocalHost = true;
            };
            worker.rpc = {
              grpcPort = 7239;
              membershipPort = 6939;
              bindOnLocalHost = true;
            };
          };
          clusterMetadata = {
            enableGlobalNamespace = false;
            failoverVersionIncrement = 10;
            masterClusterName = "active";
            currentClusterName = "active";
            clusterInformation.active = {
              enabled = true;
              initialFailoverVersion = 1;
              rpcName = "frontend";
              rpcAddress = "127.0.0.1:${toString temporalPort}";
            };
          };
          dcRedirectionPolicy.policy = "noop";
          publicClient.hostPort = "127.0.0.1:${toString temporalPort}";
        };
      };

      # The temporalio/auto-setup image creates databases, schemas and the
      # default namespace on every start; the native server does none of that,
      # so it is replicated with two idempotent oneshots.
      systemd.services."${service}-temporal-schema" = {
        description = "Set up Temporal PostgreSQL schemas for Postiz";
        # postgresql.target includes postgresql-setup.service, which creates
        # the databases and users from ensureDatabases/ensureUsers.
        after = [ "postgresql.target" ];
        requires = [ "postgresql.target" ];
        path = [
          config.services.postgresql.package
          config.services.temporal.package
        ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          User = "postgres";
          Group = "postgres";
        };
        script = ''
          set -euo pipefail

          # ensureDatabases cannot create a database whose name differs from
          # its owning user, so the visibility database is created here.
          if [ "$(psql -tAc "SELECT 1 FROM pg_database WHERE datname = '${temporalVisibilityDb}'")" != "1" ]; then
            createdb --owner=${temporalUser} ${temporalVisibilityDb}
          fi

          setup_db() {
            db="$1"
            schema_dir="$2"
            initialized="$(psql -h 127.0.0.1 -p ${toString pgPort} -U ${temporalUser} -d "$db" -tAc "SELECT to_regclass('schema_version') IS NOT NULL")"
            if [ "$initialized" != "t" ]; then
              ${temporalSqlTool} --db "$db" setup-schema -v 0.0
            fi
            ${temporalSqlTool} --db "$db" update-schema -d "$schema_dir"
          }

          setup_db ${temporalDb} ${temporalSchemaDir}/temporal/versioned
          setup_db ${temporalVisibilityDb} ${temporalSchemaDir}/visibility/versioned
        '';
      };

      systemd.services."${service}-temporal-namespace" = {
        description = "Register the default Temporal namespace for Postiz";
        after = [ "temporal.service" ];
        requires = [ "temporal.service" ];
        path = [ pkgs.temporal-cli ];
        environment = {
          # temporal-cli refuses to run without a resolvable user config dir;
          # the DynamicUser sandbox defines no HOME. Point it at the private
          # RuntimeDirectory below, which only exists for the unit's lifetime.
          HOME = "/run/${service}-temporal-namespace";
        };
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          DynamicUser = true;
          RuntimeDirectory = "${service}-temporal-namespace";
          RuntimeDirectoryMode = "0700";
        };
        script = ''
          set -euo pipefail
          address="127.0.0.1:${toString temporalPort}"

          # The frontend needs a moment after service start before it accepts requests.
          for _ in $(seq 1 30); do
            if temporal operator cluster health --address "$address" >/dev/null 2>&1; then
              break
            fi
            sleep 2
          done

          if ! temporal operator namespace describe --address "$address" -n default >/dev/null 2>&1; then
            temporal operator namespace create --address "$address" --retention 72h -n default
          fi
        '';
      };

      systemd.services.temporal = {
        after = [
          "postgresql.target"
          "${service}-temporal-schema.service"
        ];
        requires = [
          "postgresql.target"
          "${service}-temporal-schema.service"
        ];
      };

      # Only containers may reach the Temporal frontend; the LAN-facing
      # interfaces stay closed.
      networking.firewall.interfaces."podman+".allowedTCPPorts = [ temporalPort ];

      environment.systemPackages = [
        pkgs.temporal-cli # for manual inspection of the Postiz workflows
      ];

      virtualisation = {
        podman.enable = true;
        oci-containers = {
          containers = {
            # see https://github.com/gitroomhq/postiz-docker-compose/blob/main/docker-compose.yaml
            # PostgreSQL, Redis and Temporal run as native NixOS services; only
            # the Postiz app itself remains a container.
            "postiz-app" = {
              image = "ghcr.io/gitroomhq/postiz-app:${postiz-version}";
              autoStart = true;
              volumes = [
                "${cfg.stateDir}/config:/config"
                "${cfg.uploadDir}:/uploads"
                "/run/postgresql:/run/postgresql"
                "${redisSocketDir}:/run/redis"
              ];
              ports = [
                "${cfg.listenAddress}:${toString cfg.listenPort}:5000"
              ];
              environmentFiles = [ cfg.secretEnvironmentFile ];
              environment = {
                # === Required Settings
                MAIN_URL = "https://${cfg.url}";
                FRONTEND_URL = "https://${cfg.url}";
                NEXT_PUBLIC_BACKEND_URL = "https://${cfg.url}/api";
                # JWT_SECRET = "random string that is unique to every install"; # is set in secretEnvironmentFile
                DATABASE_URL = "postgresql://${cfg.user}@localhost:${toString pgPort}/${postizPostgresDb}?host=/run/postgresql";
                REDIS_URL = "redis://localhost?path=/run/redis/redis.sock";
                BACKEND_INTERNAL_URL = "http://localhost:3000";
                TEMPORAL_ADDRESS = "host.containers.internal:${toString temporalPort}";
                IS_GENERAL = "true";
                DISABLE_REGISTRATION = "false";
                RUN_CRON = "true";

                # === Storage Settings
                STORAGE_PROVIDER = "local";
                UPLOAD_DIRECTORY = "/uploads";
                NEXT_PUBLIC_UPLOAD_DIRECTORY = "/uploads";

                # === Social Media API Settings
                # are done in cfg.secretEnvironmentFile

                # === Misc Settings
                NEXT_PUBLIC_DISCORD_SUPPORT = "";
                NEXT_PUBLIC_POLOTNO = "";
                API_LIMIT = "30";

                # === Payment / Stripe Settings
                FEE_AMOUNT = "0.05";

                # === Developer Settings
                NX_ADD_PLUGINS = "false";

                # === Short Link Service Settings (Optional - leave blank if unused)
              };
              extraOptions =
                [
                  # Run the container in a user namespace: the image's nginx/pm2
                  # setup requires root *inside* the container, but that root is
                  # mapped to the unprivileged postiz user on the host (peer auth
                  # towards PostgreSQL and upload ownership follow from this).
                  # All other container ids map to an otherwise unused sub-id range.
                  "--uidmap=0:${toString cfg.uid}:1"
                  "--uidmap=1:100000:65535"
                  "--gidmap=0:${toString cfg.gid}:1"
                  "--gidmap=1:100000:65535"
                ]
                ++ lib.optional (
                  !config.virtualisation.podman.defaultNetwork.settings.dns_enabled
                ) "--add-host=host.containers.internal:${podmanBridgeIp}";
            };
          };
        };
      };
      systemd.services."podman-postiz-app" = {
        after = [
          "network-online.target"
          "postgresql.target"
          "redis-${service}.service"
          "temporal.service"
          "${service}-temporal-namespace.service"
        ];
        requires = [
          "postgresql.target"
          "redis-${service}.service"
          "temporal.service"
          "${service}-temporal-namespace.service"
        ];
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
