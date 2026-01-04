{
  config,
  lib,
  pkgs,
  machinesSensitiveVars,
  ...
}:

{
  age.identityPaths = [ "/persist/ssh/id_ed25519_wsl_env_data_indexer" ];

  wsl = {
    enable = true;
    defaultUser = "${lib.toLower machinesSensitiveVars.WslEnvDataIndexer.userName}";
    wslConf = {
      automount.enabled = false; # disable automatic mounting of Windows drives
      interop.appendWindowsPath = false; # do not append Windows PATH to WSL PATH
      user.default = machinesSensitiveVars.WslEnvDataIndexer.userName;
    };
  };

  users.users = {
    "${lib.toLower machinesSensitiveVars.WslEnvDataIndexer.userName}" = {
      hashedPasswordFile = config.age.secrets.hashedUserPassword.path;
    };
  };

  networking = {
    hostName = machinesSensitiveVars.WslEnvDataIndexer.hostName;
    usePredictableInterfaceNames = true; # use predictable interface names to avoid issues with interface names changing on reboot
  };

  imports = [
    ./secrets
  ];

  environment.systemPackages =
    with pkgs;
    [
    ];

  services.data-indexer.enable = true;

  services.deadman-ping = {
    enable = true;
    credentialsFile = config.age.secrets.deadmanPingEnvWslEnvDataIndexer.path;
  };
}
