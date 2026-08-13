{
  config,
  lib,
  pkgs,
  pkgsUnstable,
  ...
}:
let
  service = "dmarc-monitor";
  cfg = config.homelab.services.${service};
  cfgAlertmanager = config.homelab.services.alertmanager;

  # parsedmarc comes from pkgsUnstable (decision 2026-08-13): the nixos-26.05 package
  # is marked broken (upstream issue https://github.com/domainaware/parsedmarc/issues/464)
  # and 9.6.0 additionally hard-pins msgraph-core==0.2.2 against the 1.4.0 that 26.05
  # ships, so it does not even build with the broken flag overridden. The
  # unstable 10.2.0 builds and passes the selftest below. prometheus-client
  # must share the same interpreter, so the whole environment comes from
  # unstable.
  pythonEnv = pkgsUnstable.python3.withPackages (ps: [
    ps.prometheus-client
    ps.parsedmarc
  ]);

  dmarc-monitor = pkgs.stdenv.mkDerivation {
    pname = service;
    version = "1.0.0";
    src = lib.sources.sourceFilesBySuffices ./. [
      ".py"
      ".xml"
    ];
    dontConfigure = true;
    dontBuild = true;
    doCheck = true;
    nativeCheckInputs = [ pythonEnv ];
    # The selftest pins parsedmarc CLI behavior and the verdict mapping: an
    # upstream format change fails the deploy build before activation instead
    # of misjudging mails in production.
    checkPhase = ''
      runHook preCheck
      python3 dmarc_monitor.py selftest fixtures
      runHook postCheck
    '';
    installPhase = ''
      runHook preInstall
      mkdir -p $out/share/${service}
      cp -r dmarc_monitor.py fixtures $out/share/${service}/
      runHook postInstall
    '';
  };
in
{
  options.homelab.services.${service} = {
    enable = lib.mkEnableOption "the DMARC monitor";
    # Intentionally no stateDir option for the restic backup: the state files
    # are a replayable projection of the mailbox -- wipe them, move the
    # archive back to INBOX, and the counters rebuild exactly. The mailbox is
    # the backup. (The real directory also sits below /var/lib/private due to
    # DynamicUser; restic would capture the /var/lib path as a bare symlink.)
    imap = {
      host = lib.mkOption {
        type = lib.types.str;
        description = "IMAP host of the mailbox the DMARC aggregate reports (rua=) are delivered to.";
        example = "mail.example.com";
      };
      port = lib.mkOption {
        type = lib.types.port;
        default = 993;
        description = "IMAPS port of `imap.host`; the exporter always connects with TLS.";
      };
      username = lib.mkOption {
        type = lib.types.str;
        description = "Login of the report mailbox.";
        example = "dmarc@example.com";
      };
      passwordFile = lib.mkOption {
        type = lib.types.path;
        default = config.age.secrets.dmarcImapPassword.path;
        description = ''
          File containing the password of the report mailbox. The mailbox check
          and the monitor read it directly at connect time via a shared secret
          group; it never crosses a shell, a configuration file or the Nix
          store. A store path assigned here would be world-readable like any
          other store path.
        '';
      };
    };
    folders = {
      inbox = lib.mkOption {
        type = lib.types.str;
        default = "INBOX";
        description = "Unprocessed incoming mail";
      };
      archive = lib.mkOption {
        type = lib.types.str;
        default = "INBOX/Reports";
        description = "Compliant reports and acknowledged mails end up here";
      };
      failed = lib.mkOption {
        type = lib.types.str;
        default = "INBOX/Failed_Reports";
        description = "Open non-compliant reports; a mail here is a firing alert";
      };
      invalid = lib.mkOption {
        type = lib.types.str;
        default = "INBOX/Invalid_Reports";
        description = "Open unparsable mails; a mail here is a firing alert";
      };
    };
    pollIntervalSeconds = lib.mkOption {
      type = lib.types.int;
      default = 1800; # 30 min
      description = "Mailbox poll cadence; derived from the accepted arrival-to-alert latency of 1 h";
    };
    alertmanagerUrl = lib.mkOption {
      type = lib.types.str;
      default = "http://127.0.0.1:${toString cfgAlertmanager.listenPort}";
    };
    prometheus = {
      listenPort = lib.mkOption {
        type = lib.types.int;
        default = 9797;
        description = "Port where the ${service} Prometheus metrics are exposed";
      };
      scrapeConfig = lib.mkOption {
        type = lib.types.attrs;
        default = {
          job_name = service;
          static_configs = [
            {
              targets = [ "localhost:${toString cfg.prometheus.listenPort}" ];
            }
          ];
        };
        description = "Prometheus scrape configuration for ${service}.";
      };
    };
  };

  config =
    let
      # The monitor and the check run with DynamicUser, so their transient
      # users cannot own the agenix secret. A dedicated group on the secret
      # plus SupplementaryGroups on both units hands the password over without
      # giving up the hardening that DynamicUser implies.
      secretGroup = "dmarc-secret";

      mailboxCheck = "dmarc-mailbox-check";
      # Logs in and runs STATUS on the folders the monitor depends on, which
      # covers its silent failure modes: a login that stopped working and a
      # folder that no longer exists (the monitor never creates folders, they
      # are operator-managed). It does not prove write and move permissions on
      # the target folders, that would mean creating and deleting a message in
      # a live mailbox. Written against imaplib, the same library the monitor
      # itself uses: the password is passed to the IMAP client as a value and
      # never crosses a shell or a configuration file syntax, and a failed
      # login raises, which fails the unit without relying on the exit code
      # conventions of an external tool.
      mailboxCheckScript =
        pkgs.writers.writePython3Bin mailboxCheck
          {
            flakeIgnore = [ "E501" ];
          }
          ''
            import imaplib
            import ssl
            import sys

            # Rendered with toJSON rather than interpolated bare: a quote or a
            # backslash in a login or folder name would otherwise break this source.
            HOST = ${builtins.toJSON cfg.imap.host}
            PORT = ${toString cfg.imap.port}
            USER = ${builtins.toJSON cfg.imap.username}
            PASSWORD_FILE = ${builtins.toJSON (toString cfg.imap.passwordFile)}
            FOLDERS = [${
              # toJSON per element, joined by hand: toJSON on the whole list
              # renders "a","b" without the space after the comma that flake8
              # (E231) requires of the generated source.
              lib.concatMapStringsSep ", " builtins.toJSON [
                cfg.folders.inbox
                cfg.folders.archive
                cfg.folders.failed
                cfg.folders.invalid
              ]
            }]


            def imap_quote(name):
                """Quote a mailbox as an IMAP quoted-string, see RFC 3501 4.3.

                imaplib passes the mailbox through verbatim, so a name with
                spaces would arrive as several arguments, and an embedded quote
                or backslash would end the string early.
                """
                return '"%s"' % name.replace("\\", "\\\\").replace('"', '\\"')


            with open(PASSWORD_FILE) as handle:
                password = handle.read().rstrip("\n")

            # imaplib defaults to ssl._create_stdlib_context(), which verifies
            # neither the certificate chain nor the hostname, while the password
            # goes over the wire immediately after the handshake.
            context = ssl.create_default_context()

            # timeout: a server that accepts the connection and then goes
            # silent must fail this check instead of hanging it forever.
            with imaplib.IMAP4_SSL(HOST, PORT, ssl_context=context, timeout=60) as imap:
                imap.login(USER, password)
                for folder in FOLDERS:
                    status, detail = imap.status(imap_quote(folder), "(MESSAGES)")
                    if status != "OK":
                        sys.exit("IMAP folder %s is not usable: %s" % (folder, detail))
          '';
    in
    lib.mkIf cfg.enable {
      users.groups.${secretGroup} = { };

      # Alert rules are appended to the Prometheus configuration via NixOS
      # module merge: the service owning the metrics declares them, Prometheus
      # only aggregates. Only the watcher's own liveness lives here -- report
      # verdicts deliberately never go through Prometheus rules, the
      # acknowledgeable alerts are posted to the Alertmanager API by the
      # monitor itself.
      services.prometheus.ruleFiles = lib.mkIf config.services.prometheus.enable [
        (pkgs.writeText "dmarc-monitor.rules.yml" (
          builtins.toJSON {
            groups = [
              {
                name = service;
                rules = [
                  {
                    # Catches a hung monitor whose /metrics endpoint still
                    # answers; TargetDown catches a dead one, SystemdUnitFailed
                    # a crash-looping one. Self-resolving is correct here: this
                    # is infrastructure state, not an event with a review duty.
                    alert = "DmarcMonitorStale";
                    expr = "time() - dmarc_last_successful_run_timestamp_seconds > 3 * ${toString cfg.pollIntervalSeconds}";
                    for = "0m";
                    labels = {
                      severity = "warning";
                    };
                    annotations = {
                      summary = "dmarc-monitor has not completed a cycle for over {{ $value | humanizeDuration }} (instance {{ $labels.instance }})";
                    };
                  }
                ];
              }
            ];
          }
        ))
      ];

      systemd.services."${service}" = {
        description = "Mailbox-driven DMARC report evaluation";
        # Ordering only, deliberately no `requires` on the check: this monitor
        # never creates folders and fails cycles softly with retry, so running
        # against a broken mailbox does no harm -- while a hard coupling would
        # turn one transient check failure into a permanently stopped (not
        # failed, hence unalerted) monitor. The check is a watchdog that makes
        # misconfiguration loud, not a gate.
        after = [
          "network-online.target"
          "${mailboxCheck}.service"
        ];
        wants = [ "network-online.target" ];
        wantedBy = [ "multi-user.target" ];
        path = [ pythonEnv ]; # parsedmarc must be resolvable via PATH
        environment = {
          DMARC_IMAP_HOST = cfg.imap.host;
          DMARC_IMAP_PORT = toString cfg.imap.port;
          DMARC_IMAP_USERNAME = cfg.imap.username;
          DMARC_IMAP_PASSWORD_FILE = toString cfg.imap.passwordFile;
          DMARC_FOLDER_INBOX = cfg.folders.inbox;
          DMARC_FOLDER_ARCHIVE = cfg.folders.archive;
          DMARC_FOLDER_FAILED = cfg.folders.failed;
          DMARC_FOLDER_INVALID = cfg.folders.invalid;
          DMARC_POLL_INTERVAL_SECONDS = toString cfg.pollIntervalSeconds;
          DMARC_ALERTMANAGER_URL = cfg.alertmanagerUrl;
          DMARC_METRICS_PORT = toString cfg.prometheus.listenPort;
        };
        serviceConfig = {
          DynamicUser = true;
          SupplementaryGroups = [ secretGroup ];
          Restart = "on-failure";
          RestartSec = 30;
          StateDirectory = service;
          StateDirectoryMode = "0700";
          ExecStart = "${pythonEnv}/bin/python3 ${dmarc-monitor}/share/${service}/dmarc_monitor.py run";
          StandardOutput = "journal";
          StandardError = "journal";

          # This unit fetches and parses attacker-controlled mail content (the
          # rua= address is public DNS), so it gets the strictest profile in the
          # repo. The caps below are anomaly ceilings, not allocations: they
          # reserve nothing and only fire when hostile input runs away. They
          # are sized above the legitimate worst case, because a cap that a
          # real report can hit would misjudge it as invalid -- tightening
          # buys no additional containment (bounded is bounded), it only
          # shifts risk from the attacker to legitimate reports:
          #  - MemoryMax = parser child cap (400M address space, the ceiling
          #    a large legitimate report can reach, see dmarc_monitor.py)
          #    plus daemon (~50M) plus margin; the child dies first, the
          #    daemon survives and judges the mail invalid.
          #  - CPUQuota (half a core) with the 60 s parse timeout bounds a
          #    runaway to <= 30 CPU-seconds per mail; a normal parse needs
          #    1-2 s.
          #  - TasksMax is twice the observed peak (~8 tasks: main thread,
          #    metrics HTTP threads, sh -> parsedmarc child with its
          #    threads); a fork bomb is equally dead at any small value.
          MemoryMax = "512M";
          TasksMax = 16;
          CPUQuota = "50%";

          CapabilityBoundingSet = [ "" ];
          LockPersonality = true;
          MemoryDenyWriteExecute = true;
          NoNewPrivileges = true;
          PrivateDevices = true;
          PrivateMounts = true;
          PrivateTmp = true;
          PrivateUsers = true;
          ProcSubset = "pid";
          ProtectClock = true;
          ProtectControlGroups = true;
          ProtectHome = true;
          ProtectHostname = true;
          ProtectKernelLogs = true;
          ProtectKernelModules = true;
          ProtectKernelTunables = true;
          ProtectProc = "invisible";
          ProtectSystem = "strict";
          # The parser child needs more than plain TCP: without AF_UNIX
          # (nscd/NSS) and AF_NETLINK (glibc getaddrinfo).
          # The mailbox check below keeps the narrower set, plain imaplib needs neither.
          RestrictAddressFamilies = [
            "AF_INET"
            "AF_INET6"
            "AF_UNIX"
            "AF_NETLINK"
          ];
          RestrictNamespaces = true;
          RestrictRealtime = true;
          RestrictSUIDSGID = true;
          SystemCallArchitectures = "native";
          SystemCallFilter = [
            "@system-service"
            "~@privileged"
          ];
          UMask = "0077";
        };
      };

      # The monitor keeps serving its metrics endpoint while IMAP cycles fail,
      # so a wrong password, a locked mailbox or a renamed folder would stay
      # invisible until DmarcMonitorStale fires. This check exercises the login
      # and every folder the monitor depends on, and fails the unit if any of
      # it breaks, which the existing SystemdUnitFailed alert picks up. No
      # second alerting mechanism, and it does not depend on any metric the
      # monitor exposes.
      systemd.services.${mailboxCheck} = {
        description = "Check that the DMARC report mailbox is reachable and its folders exist";
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];
        # Also run at boot, not only on the timer below: waiting up to a day to
        # learn that the credentials or the folder names are wrong defeats the
        # purpose of the check.
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          # No RemainAfterExit: a oneshot that stays active would never be
          # started again by the timer below, silently turning the daily check
          # into a boot-only check. Inactive after success is correct -- a
          # failed run leaves the unit in failed state, which SystemdUnitFailed
          # alerts on, and the next successful run clears it.
          Type = "oneshot";
          ExecStart = "${mailboxCheckScript}/bin/${mailboxCheck}";
          DynamicUser = true;
          SupplementaryGroups = [ secretGroup ];
          LockPersonality = true;
          MemoryDenyWriteExecute = true;
          NoNewPrivileges = true;
          PrivateDevices = true;
          PrivateTmp = true;
          ProtectClock = true;
          ProtectControlGroups = true;
          ProtectHome = true;
          ProtectHostname = true;
          ProtectKernelLogs = true;
          ProtectKernelModules = true;
          ProtectKernelTunables = true;
          ProtectProc = "invisible";
          ProtectSystem = "strict";
          RestrictAddressFamilies = [
            "AF_INET"
            "AF_INET6"
          ];
          RestrictNamespaces = true;
          RestrictRealtime = true;
          RestrictSUIDSGID = true;
          SystemCallArchitectures = "native";
          SystemCallFilter = [
            "@system-service"
            "~@privileged"
          ];
          UMask = "0077";
        };
      };

      systemd.timers.${mailboxCheck} = {
        description = "Daily reachability check of the DMARC report mailbox";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = "daily";
          RandomizedDelaySec = "1h";
          Persistent = true; # catch up after downtime instead of skipping a day
        };
      };
    };
}
