{ lib, inputs, ... }:
{
  age.identityPaths = ["/persist/ssh/ssh_host_ed25519_main_server"];

  age.secrets.hashedUserPassword.file = ./hashedUserPassword.age;  # content is result of: `mkpasswd -m sha-512`

  age.secrets.sambaPassword.file = ./sambaPassword.age;

  age.secrets.tailscaleAuthKey.file = ../../secrets/tailscaleAuthKey.age; # generate for max 90 day at https://login.tailscale.com/admin/settings/keys
                                  # cd secrets && EDITOR=nano nix --experimental-features 'nix-command flakes' run github:ryantm/agenix -- -e tailscaleAuthKey.age
}
