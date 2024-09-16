let
  jakob = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOquQ/e3s3yYUYjwk2vth18wWGTNlOmNUzjPXUzKeXZI 20231225_jakob_lichterfeld";
  MainServer = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIN864FN+RrNE1z3xYtZQlybMHfnMzos10wqOKNWYEQaF MainServer";
  allKeys = [
    jakob
    MainServer
  ];
in
{
  "hashedUserPassword.age".publicKeys = allKeys;
  "sambaPassword.age".publicKeys = allKeys;
  "tailscaleAuthKey.age".publicKeys = allKeys;
  "dnsApiCredentials.age".publicKeys = allKeys;
}

# to add a secret run `EDITOR=nano nix --experimental-features 'nix-command flakes' run github:ryantm/agenix -- -e hashedUserPassword.age`
