{ lib, inputs, ... }:
{
  age.identityPaths = ["/persist/ssh/ssh_host_ed25519_main_server"];

  age.secrets.hashedUserPassword = lib.mkDefault {
    file = ./hashedUserPassword.age;  # content is result of: `mkpasswd -m sha-512`
                                      # cd secrets && EDITOR=nano nix --experimental-features 'nix-command flakes' run github:ryantm/agenix -- -e hashedUserPassword.age
  };
  age.secrets.sambaPassword = lib.mkDefault {
    file = ./sambaPassword.age;
    };
  age.secrets.tailscaleAuthKey = lib.mkDefault {
      file = ./tailscaleAuthKey.age; # generate for max 90 day at https://login.tailscale.com/admin/settings/keys
                                    # cd secrets && EDITOR=nano nix --experimental-features 'nix-command flakes' run github:ryantm/agenix -- -e tailscaleAuthKey.age
    };

  # MainDev
  age.secrets.MainDev_hostName = lib.mkDefault {
    file = ./MainDev_hostName.age;
    };

  age.secrets.MainDev_ipAddress = lib.mkDefault {
    file = ./MainDev_ipAddress.age;
    };
  age.secrets.MainDev_ipNetwork = lib.mkDefault {
    file = ./MainDev_ipNetwork.age;
    };
  age.secrets.MainDev_defaultGateway = lib.mkDefault {
    file = ./MainDev_defaultGateway.age;
    };
  age.secrets.MainDev_username = lib.mkDefault {
    file = ./MainDev_username.age;
    };
  age.secrets.MainDev_sshPort = lib.mkDefault {
    file = ./MainDev_sshPort.age;
    };

  # MainServer
  age.secrets.MainServer_hostName = lib.mkDefault {
    file = ./MainServer_hostName.age;
    };
  age.secrets.MainServer_ipAddress = lib.mkDefault {
    file = ./MainServer_ipAddress.age;
    };
  age.secrets.MainServer_ipAddress2 = lib.mkDefault {
    file = ./MainServer_ipAddress2.age;
    };
  age.secrets.MainServer_ipNetwork = lib.mkDefault {
    file = ./MainServer_ipNetwork.age;
    };
  age.secrets.MainServer_defaultGateway = lib.mkDefault {
    file = ./MainServer_defaultGateway.age;
    };
  age.secrets.MainServer_username = lib.mkDefault {
    file = ./MainServer_username.age;
    };
  age.secrets.MainServer_sshPort = lib.mkDefault {
    file = ./MainServer_sshPort.age;
    };
  age.secrets.MainServer_hostId = lib.mkDefault {
    file = ./MainServer_hostId.age;
    };
  age.secrets.MainServer_timeZone = lib.mkDefault {
    file = ./MainServer_timeZone.age;
    };
  age.secrets.MainServer_nameservers = lib.mkDefault {
    file = ./MainServer_nameservers.age;
    };
}
