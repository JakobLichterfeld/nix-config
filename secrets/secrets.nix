let
  jakob = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOquQ/e3s3yYUYjwk2vth18wWGTNlOmNUzjPXUzKeXZI 20231225_jakob_lichterfeld";
  christine = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIF84aG1HPkRvbIQYiZEXm84zuLMs7Owq6pCdTKLMh3Eo 20250706_christine_lichterfeld";
  MainServer = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIN864FN+RrNE1z3xYtZQlybMHfnMzos10wqOKNWYEQaF MainServer";
  serverAndJakob = [
    jakob
    MainServer
  ];
  serverAndChristine = [
    christine
    MainServer
  ];
  allKeys = [
    jakob
    christine
    MainServer
  ];
in
{
  "deadmanPingEnvMainServer.age".publicKeys = allKeys;
  "dnsApiCredentials.age".publicKeys = allKeys;
  "fritzboxExporterEnv.age".publicKeys = allKeys;
  "hashedUserPassword.age".publicKeys = serverAndJakob;
  "hashedUserPasswordChristine.age".publicKeys = serverAndChristine;
  "linkwardenEnv.age".publicKeys = allKeys;
  "paperlessEnv.age".publicKeys = allKeys;
  "paperlessPassword.age".publicKeys = allKeys;
  "resticPassword.age".publicKeys = allKeys;
  "s3StorageEnv.age".publicKeys = allKeys;
  "sambaPassword.age".publicKeys = serverAndJakob;
  "sambaPasswordChristine.age".publicKeys = serverAndChristine;
  "smtpPassword.age".publicKeys = serverAndJakob;
"syncthingGuiPassword.age".publicKeys = serverAndJakob;
  "tailscaleAuthKey.age".publicKeys = allKeys;
  "telegramCredentials.age".publicKeys = allKeys;
  "teslamateEnv.age".publicKeys = allKeys;
  "teslamateEnvABRP.age".publicKeys = allKeys;
  "teslamateEnvTelegramBot.age".publicKeys = allKeys;
  "vaultwardenEnv.age".publicKeys = serverAndJakob;
}

# to add a secret run `EDITOR=nano nix --experimental-features 'nix-command flakes' run github:ryantm/agenix -- -e hashedUserPassword.age`
