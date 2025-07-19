{
  config,
  inputs,
  pkgs,
  lib,
  machinesSensitiveVars,
  ...
}:
{
  nix.settings.trusted-users = [ "jakob" ];

  users = {
    users = {
      jakob = {
        name = "jakob";
        home = "/home/jakob";
        uid = 1000;
        isNormalUser = true;
        hashedPasswordFile = config.age.secrets.hashedUserPassword.path;
        extraGroups = [
          "wheel"
          "users"
          "video"
          "podman"
          "input"
          (lib.toLower machinesSensitiveVars.OperatingCompany.name)
          (lib.toLower machinesSensitiveVars.HoldingCompanyJakob.name)
        ];
        group = "jakob";
        openssh.authorizedKeys.keys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOquQ/e3s3yYUYjwk2vth18wWGTNlOmNUzjPXUzKeXZI 20231225_jakob_lichterfeld"
        ];
      };
      ${lib.toLower machinesSensitiveVars.OperatingCompany.name} = {
        name = lib.toLower machinesSensitiveVars.OperatingCompany.name;
        uid = 2000;
        isSystemUser = true;
        group = lib.toLower machinesSensitiveVars.OperatingCompany.name;
        createHome = false;
      };
      ${lib.toLower machinesSensitiveVars.HoldingCompanyJakob.name} = {
        name = lib.toLower machinesSensitiveVars.HoldingCompanyJakob.name;
        uid = 3000;
        isSystemUser = true;
        group = lib.toLower machinesSensitiveVars.HoldingCompanyJakob.name;
        createHome = false;
      };
    };
    groups = {
      jakob = {
        gid = 1000;
      };
      ${lib.toLower machinesSensitiveVars.OperatingCompany.name} = {
        gid = 2000;
      };
      ${lib.toLower machinesSensitiveVars.HoldingCompanyJakob.name} = {
        gid = 3000;
      };
    };
  };

}
