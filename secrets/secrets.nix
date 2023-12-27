let
  jakob = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOquQ/e3s3yYUYjwk2vth18wWGTNlOmNUzjPXUzKeXZI 20231225_jakob_lichterfeld";
  allKeys = [jakob];
in {
  "hashedUserPassword.age".publicKeys = allKeys;
  # "sambaPassword.age".publicKeys = allKeys;
  # "smtpPassword.age".publicKeys = allKeys;
  # "telegramChannelId.age".publicKeys = allKeys;
  # "telegramApiKey.age".publicKeys = allKeys;
  # "wireguardCredentials.age".publicKeys = allKeys;
  # "cloudflareDnsApiCredentials.age".publicKeys = allKeys;
  # "invoiceNinja.age".publicKeys = allKeys;
  # "radarrApiKey.age".publicKeys = allKeys;
  # "sonarrApiKey.age".publicKeys = allKeys;
  "tailscaleAuthKey.age".publicKeys = allKeys;
  # "paperless.age".publicKeys = allKeys;
  # "resticBackblazeEnv.age".publicKeys = allKeys;
  # "resticPassword.age".publicKeys = allKeys;
  # "wireguardPrivateKey.age".publicKeys = allKeys;
  # "bwSessionFish.age".publicKeys = allKeys;
  # "icloudDrive.age".publicKeys = allKeys;
  # "icloudDriveUsername.age".publicKeys = allKeys;
}

# to add a secret run `EDITOR=nano nix --experimental-features 'nix-command flakes' run github:ryantm/agenix -- -e hashedUserPassword.age`
