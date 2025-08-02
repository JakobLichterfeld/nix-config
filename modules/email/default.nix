{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.email;
in
{
  options.email = {
    enable = lib.mkEnableOption "Email sending functionality";
    fromAddress = lib.mkOption {
      description = "The 'from' address";
      type = lib.types.str;
      example = "john@example.com";
    };
    toAddress = lib.mkOption {
      description = "The 'to' address";
      type = lib.types.str;
      example = "john@example.com";
    };
    smtpServer = lib.mkOption {
      description = "The SMTP server address";
      type = lib.types.str;
      example = "smtp.example.com";
    };
    smtpPort = lib.mkOption {
      type = lib.types.int;
      default = 587;
      description = "SMTP server port";
    };
    smtpUsername = lib.mkOption {
      description = "The SMTP username";
      type = lib.types.str;
      example = "john@example.com";
    };
    smtpPasswordPath = lib.mkOption {
      description = "Path to the secret containing SMTP password";
      type = lib.types.path;
      example = "/secrets/smtpPassword";
    };
  };

  config = lib.mkIf cfg.enable {

    assertions = [
      {
        assertion = cfg.fromAddress != "";
        message = "From address must be set.";
      }
      {
        assertion = cfg.toAddress != "";
        message = "To address must be set.";
      }
      {
        assertion = cfg.smtpServer != "";
        message = "SMTP server must be set.";
      }
      {
        assertion = cfg.smtpUsername != "";
        message = "SMTP username must be set.";
      }
      {
        assertion = cfg.smtpPasswordPath != ""; # no check with builtins.pathExists, as agenix secrets are not available at build time
        message = "SMTP password path must be set.";
      }
    ];

    programs.msmtp = {
      enable = true;
      setSendmail = true; # Set the system sendmail to msmtp
      accounts.default = {
        auth = true;
        host = cfg.smtpServer;
        port = cfg.smtpPort;
        from = cfg.fromAddress;
        user = cfg.smtpUsername;
        tls = true;
        passwordeval = "${pkgs.coreutils}/bin/cat ${cfg.smtpPasswordPath}";
      };
    };

    systemd.services.test-email = {
      enable = false;
      script = ''
        echo "It works!" | /run/wrappers/bin/sendmail -v ${cfg.toAddress}
      '';
      wantedBy = [ "multi-user.target" ];
    };
  };

}
