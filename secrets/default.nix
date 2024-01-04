{ lib, inputs, ... }:
{
  age.identityPaths = ["/persist/ssh/ssh_host_ed25519_main_server"];

  age.secrets.hashedUserPassword = lib.mkDefault {
    file = ./hashedUserPassword.age;  # content is result of: `mkpasswd -m sha-512`
                                      # cd secrets && EDITOR=nano nix --experimental-features 'nix-command flakes' run github:ryantm/agenix -- -e hashedUserPassword.age
  };
  age.secrets.sambaPassword = lib.mkDefault {
    file = ./sambaPassword.age;
    };
  age.secrets.tailscaleAuthKey = lib.mkDefault {
      file = ./tailscaleAuthKey.age; # generate for max 90 day at https://login.tailscale.com/admin/settings/keys
                                    # cd secrets && EDITOR=nano nix --experimental-features 'nix-command flakes' run github:ryantm/agenix -- -e tailscaleAuthKey.age
    };
}
