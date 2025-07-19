{
  config,
  inputs,
  pkgs,
  lib,
  machinesSensitiveVars,
  ...
}:
{
  nix.settings.trusted-users = [ "christine" ];

  users = {
    users = {
      christine = {
        name = "christine";
        home = "/home/christine";
        uid = 1001;
        isNormalUser = true;
        hashedPasswordFile = config.age.secrets.hashedUserPasswordChristine.path;
        extraGroups = [
          "wheel"
          "users"
          "video"
          "podman"
          "input"
          (lib.toLower machinesSensitiveVars.OperatingCompany.name)
          (lib.toLower machinesSensitiveVars.HoldingCompanyChristine.name)
        ];
        group = "christine";
        openssh.authorizedKeys.keys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIF84aG1HPkRvbIQYiZEXm84zuLMs7Owq6pCdTKLMh3Eo 20250706_christine_lichterfeld"
        ];
      };
      ${lib.toLower machinesSensitiveVars.HoldingCompanyChristine.name} = {
        name = machinesSensitiveVars.HoldingCompanyChristine.name;
        uid = 4000;
        isSystemUser = true;
        group = lib.toLower machinesSensitiveVars.HoldingCompanyChristine.name;
      };
    };
    groups = {
      christine = {
        gid = 1001;
      };
      ${lib.toLower machinesSensitiveVars.HoldingCompanyChristine.name} = {
        gid = 4000;
      };
    };
  };

}
