{
  config,
  lib,
  pkgs,
  machinesSensitiveVars,
  ...
}:
let
  hl = config.homelab;
  cfg = hl.samba;
in
{
  options.homelab.samba = {
    enable = lib.mkEnableOption {
      description = "Samba shares for the homelab";
    };
    example = lib.mkOption {
      default = lib.attrsets.mapAttrs (
        name: value: name:
        value.settings
      ) cfg.shares;
    };
    sambaUsers = lib.mkOption {
      description = "List of Samba users and their password file paths";
      type = lib.types.listOf (
        lib.types.submodule {
          options = {
            username = lib.mkOption {
              type = lib.types.str;
              description = "The Samba username";
            };
            passwordFile = lib.mkOption {
              type = lib.types.path;
              description = "Path to the encrypted Samba password file";
              default = /dev/null; # default to no password file
              example = "/path/to/passwordFile";
            };
          };
        }
      );
      default = [ ];
      example = lib.literalExpression ''
        [
          {
            username = "userOne";
            passwordFile = "/path/to/passwordFileForUserOne";
          }
          {
            userTwo = {
              passwordFile = "/path/to/passwordFileForUserTwo";
            };
          }
        ]
      '';
    };
    commonSettings = lib.mkOption {
      description = "Parameters applied to each share";
      type = lib.types.functionTo (lib.types.attrsOf lib.types.str);
      default = value: {
        "preserve case" = "yes";
        "short preserve case" = "yes";
        "browseable" = "yes"; # show share in network, does not mean accessible just visible
        "read only" = "no"; # allow write access
        "guest ok" = "no"; # do not allow guest access
        "create mask" = "0660"; # allow owner and group write access, but not others
        "directory mask" = "0770"; # allow owner and group write access, but not others
        "valid users" = ""; # set in share definition
        "fruit:aapl" = "yes"; # enable Apple File Protocol for better compatibility with macOS
        "vfs objects" = "catia fruit streams_xattr";
      };
      example = lib.literalExpression ''
        value: {
          "invalid users" = [ "root" ];
        }
      '';
    };
    shares = lib.mkOption {
      description = "Samba share definitions with paths, owners, and permissions";
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            path = lib.mkOption {
              type = lib.types.path;
              description = "Filesystem path of the share";
            };

            filesystemOwner = lib.mkOption {
              type = lib.types.str;
              default = "root";
              description = "Owner of the share directory on filesystem level";
            };

            filesystemGroup = lib.mkOption {
              type = lib.types.str;
              default = "users";
              description = "Group of the share directory on filesystem level";
            };

            validUsers = lib.mkOption {
              type = lib.types.str;
              default = "";
              description = "Samba valid users (e.g. 'username' for single user, or '@groupname' for groups)";
            };

            extraOptions = lib.mkOption {
              type = lib.types.attrsOf lib.types.str;
              default = { };
              description = "Extra Samba share-specific options";
              example = lib.literalExpression ''
                {
                  "fruit:time machine" = "yes";
                }
              '';
            };
          };
        }
      );
      example = lib.literalExpression ''
        CoolShare = {
          path = "/mnt/CoolShare";
          filesystemOwner = "shareuser";
          filesystemGroup = "users";
          validUsers = "@groupname";
          extraOptions = {
            "fruit:aapl" = "yes";
          };
        };
      '';
      default = { };
    };
  };
  config = lib.mkIf cfg.enable {
    services.samba-wsdd.enable = true; # make shares visible for windows clients

    environment.systemPackages = [ config.services.samba.package ];

    # set correct access right on filesystem level, creating directories if they do not exist
    systemd.tmpfiles.rules = lib.flatten (
      lib.attrsets.mapAttrsToList (_: x: [
        "z ${x.path} 0770 ${x.filesystemOwner} ${x.filesystemGroup} - -"
        "d ${x.path} 0770 ${x.filesystemOwner} ${x.filesystemGroup} - -"
      ]) cfg.shares
    );

    # create samba users with corresponding passwords
    system.activationScripts.samba_user_create = ''
      set -e
      ${lib.concatMapStringsSep "\n" (
        user:
        let
          name = user.username;
          pwFile = user.passwordFile;
        in
        ''
          if [ -f '${pwFile}' ]; then
            smb_password=$(cat '${pwFile}')
            echo -e "$smb_password\n$smb_password\n" | ${lib.getExe' pkgs.samba "smbpasswd"} -a -s '${name}'
          else
            echo "Password file not found for user '${name}'" >&2
            exit 1
          fi
        ''
      ) cfg.sambaUsers}
    '';

    networking.firewall = {
      allowedTCPPorts = [ 5357 ];
      allowedUDPPorts = [ 3702 ];
    };

    services.samba = {
      enable = true;
      openFirewall = true;
      settings =
        {
          global = {
            workgroup = lib.mkDefault "LAN";
            "server string" = lib.mkDefault config.networking.hostName;
            "netbios name" = lib.mkDefault config.networking.hostName;
            "security" = lib.mkDefault "user"; # user account needed for access
            "invalid users" = [ "root" ]; # do not allow root access
            "hosts allow" = lib.mkDefault (
              lib.strings.removeSuffix "0/24" machinesSensitiveVars.MainServer.ipNetwork
              + " "
              + "127.0.0.1"
              + " "
              + "localhost"
              + " "
              + "100.64.0.0/10"
            );
            "guest account" = lib.mkDefault "nobody";
            "map to guest" = lib.mkDefault "bad user";
            "passdb backend" = lib.mkDefault "tdbsam";
          };
        }
        // builtins.mapAttrs (
          _name: value:
          lib.attrsets.mergeAttrsList (
            [
              (cfg.commonSettings value)
              value.extraOptions
              {
                path = value.path;
              }
            ]
            ++ lib.optional (value.validUsers != "") {
              "valid users" = value.validUsers;
            }
          )
        ) cfg.shares;
    };
    services.avahi = {
      enable = true;
      nssmdns4 = true;
      publish = {
        enable = true;
        addresses = true;
        domain = true;
        hinfo = true;
        userServices = true;
        workstation = true;
      };
      extraServiceFiles = {
        smb = ''
          <?xml version="1.0" standalone='no'?><!--*-nxml-*-->
          <!DOCTYPE service-group SYSTEM "avahi-service.dtd">
          <service-group>
          <name replace-wildcards="yes">%h</name>
          <service>
          <type>_smb._tcp</type>
          <port>445</port>
          </service>
          </service-group>
        '';
      };
    };
  };
}
