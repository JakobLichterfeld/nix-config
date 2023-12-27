{ lib, inputs, ... }:
{
  age.identityPaths = ["/persist/ssh/ssh_host_ed25519_key"];

  age.secrets.hashedUserPassword = lib.mkDefault {
    file = ./hashedUserPassword.age;  # content is result of: `mkpasswd -m sha-512`
                                      # cd secrets && EDITOR=nano nix --experimental-features 'nix-command flakes' run github:ryantm/agenix -- -e hashedUserPassword.age
  };
  # age.secrets.sambaPassword = lib.mkDefault {
  #   file = ./sambaPassword.age;
  #   };
  # age.secrets.telegramApiKey = lib.mkDefault {
  #   file = ./telegramApiKey.age;
  #   owner = "jakob";
  #   group = "jakob";
  #   mode = "640";
  #   };
  # age.secrets.telegramChannelId = lib.mkDefault {
  #   file = ./telegramChannelId.age;
  #   owner = "jakob";
  #   group = "jakob";
  #   mode = "640";
  #   };
  # age.secrets.smtpPassword = lib.mkDefault {
  #   file = ./smtpPassword.age;
  #   owner = "jakob";
  #   group = "jakob";
  #   mode = "770";
  # };
  # age.secrets.wireguardCredentials = lib.mkDefault {
  #     file = ./wireguardCredentials.age;
  #   };
  # age.secrets.cloudflareDnsApiCredentials = lib.mkDefault {
  #     file = ./cloudflareDnsApiCredentials.age;
  #   };
  # age.secrets.invoiceNinja = lib.mkDefault {
  #     file = ./invoiceNinja.age;
  #   };
  # age.secrets.radarrApiKey = lib.mkDefault {
  #     file = ./radarrApiKey.age;
  #   };
  # age.secrets.sonarrApiKey = lib.mkDefault {
  #     file = ./sonarrApiKey.age;
  #   };
  age.secrets.tailscaleAuthKey = lib.mkDefault {
      file = ./tailscaleAuthKey.age; # generate for max 90 day at https://login.tailscale.com/admin/settings/keys
                                    # cd secrets && EDITOR=nano nix --experimental-features 'nix-command flakes' run github:ryantm/agenix -- -e tailscaleAuthKey.age
    };
  # age.secrets.paperless = lib.mkDefault {
  #     file = ./paperless.age;
  #   };
  # age.secrets.resticBackblazeEnv = lib.mkDefault {
  #     file = ./resticBackblazeEnv.age;
  #   };
  # age.secrets.resticPassword = lib.mkDefault {
  #     file = ./resticPassword.age;
  #   };
  # age.secrets.wireguardPrivateKey = lib.mkDefault {
  #     file = ./wireguardPrivateKey.age;
  #   };
  # age.secrets.bwSessionFish = lib.mkDefault {
  #     file = ./bwSessionFish.age;
  #   };
  # age.secrets.icloudDrive = lib.mkDefault {
  #     file = ./icloudDrive.age;
  #     };
  # age.secrets.icloudDriveUsername = lib.mkDefault {
  #     file = ./icloudDriveUsername.age;
  #     };
}
