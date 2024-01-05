{ config, pkgs, lib,... }:
{
  age.secrets.hashedUserPassword.file = ../../secrets/hashedUserPassword.age;  # content is result of: `mkpasswd -m sha-512`

  nix.settings.trusted-users = [ "jakob" ];

  age.identityPaths = ["/home/jakob/.ssh/id_ed25519"];

  users = {
    users = {
      jakob = {
        name = "jakob";
        home = "/Users/jakob";
        uid = 1000;
        isNormalUser = true;
        passwordFile = config.age.secrets.hashedUserPassword.path;
        extraGroups = [ "wheel" "users" "video" ];
        group = "jakob";
        openssh.authorizedKeys.keys = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOquQ/e3s3yYUYjwk2vth18wWGTNlOmNUzjPXUzKeXZI 20231225_jakob_lichterfeld" ];
      };
    };
    groups = {
      jakob = {
        gid= 1000;
      };
    };
  };

}
