let
  jakob = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOquQ/e3s3yYUYjwk2vth18wWGTNlOmNUzjPXUzKeXZI 20231225_jakob_lichterfeld";
  MainServer = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIN864FN+RrNE1z3xYtZQlybMHfnMzos10wqOKNWYEQaF MainServer";
  allKeys = [jakob MainServer];
in {
  "hashedUserPassword.age".publicKeys = allKeys;
  "sambaPassword.age".publicKeys = allKeys;
  "tailscaleAuthKey.age".publicKeys = allKeys;

  "MainDev_hostName.age".publicKeys = allKeys;
  "MainDev_ipAddress.age".publicKeys = allKeys;
  "MainDev_ipNetwork.age".publicKeys = allKeys;
  "MainDev_defaultGateway.age".publicKeys = allKeys;
  "MainDev_username.age".publicKeys = allKeys;
  "MainDev_sshPort.age".publicKeys = allKeys;

  "MainServer_hostName.age".publicKeys = allKeys;
  "MainServer_ipAddress.age".publicKeys = allKeys;
  "MainServer_ipAddress2.age".publicKeys = allKeys;
  "MainServer_ipNetwork.age".publicKeys = allKeys;
  "MainServer_defaultGateway.age".publicKeys = allKeys;
  "MainServer_username.age".publicKeys = allKeys;
  "MainServer_sshPort.age".publicKeys = allKeys;
  "MainServer_hostId.age".publicKeys = allKeys;
  "MainServer_timeZone.age".publicKeys = allKeys;
  "MainServer_nameservers.age".publicKeys = allKeys;
}

# to add a secret run `EDITOR=nano nix --experimental-features 'nix-command flakes' run github:ryantm/agenix -- -e hashedUserPassword.age`
