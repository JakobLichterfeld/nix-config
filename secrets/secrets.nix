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

  WslEnvDataIndexer = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAVF6cqDNzA7b9EgRQqC8/jZgqDDp+TmejvyccObARP8 20260102_wsl_env_data_indexer"; # private and pub key pair created with ssh-keygen -t ed25519 -a 32 -C "20260102_wsl_env_data_indexer" -f ~/.ssh/id_ed25519_wsl_env_data_indexer
  WslEnvDataIndexerAndJakob = [
    WslEnvDataIndexer
    jakob
  ];
  serverAndWslEnvDataIndexerAndJakob = [
    WslEnvDataIndexer
    MainServer
    jakob
  ];
in
{
  "dataIndexerJwt.age".publicKeys = WslEnvDataIndexerAndJakob;
  "deadmanPingEnvMainServer.age".publicKeys = allKeys;
  "deadmanPingEnvWslEnvDataIndexer.age".publicKeys = WslEnvDataIndexerAndJakob;
  "dnsApiCredentials.age".publicKeys = serverAndJakob;
  "fritzboxExporterEnv.age".publicKeys = allKeys;
  "hashedUserPassword.age".publicKeys = serverAndWslEnvDataIndexerAndJakob;
  "hashedUserPasswordChristine.age".publicKeys = serverAndChristine;
  "linkwardenEnv.age".publicKeys = allKeys;
  "matomoCloudflared.age".publicKeys = serverAndJakob;
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
  "umamiAppSecretFile.age".publicKeys = serverAndJakob;
  "umamiCloudflared.age".publicKeys = serverAndJakob;
  "vaultwardenEnv.age".publicKeys = serverAndJakob;
}
