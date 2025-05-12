{ }:
{
  age.secrets.dnsApiCredentials = {
    file = "dnsApiCredentials.age"; # content is according to the provider, see https://go-acme.github.io/lego/dns/
    # cd secrets && EDITOR=nano nix --experimental-features 'nix-command flakes' run github:ryantm/agenix -- -e dnsApiCredentials.age
  };

  age.secrets.hashedUserPassword = {
    file = "hashedUserPassword.age"; # content is result of: `mkpasswd -m sha-512`
    # cd secrets && EDITOR=nano nix --experimental-features 'nix-command flakes' run github:ryantm/agenix -- -e hashedUserPassword.age
  };

  age.secrets.sambaPassword = {
    file = "sambaPassword.age"; # content is the samba password
    # cd secrets && EDITOR=nano nix --experimental-features 'nix-command flakes' run github:ryantm/agenix -- -e sambaPassword.age
  };

  age.secrets.tailscaleAuthKey = {
    file = "tailscaleAuthKey.age"; # generate for max 180 day at https://login.tailscale.com/admin/settings/keys
    # cd secrets && EDITOR=nano nix --experimental-features 'nix-command flakes' run github:ryantm/agenix -- -e tailscaleAuthKey.age
  };

  age.secrets.tgNotifyCredentials = {
    file = "tgNotifyCredentials.age"; # content is the telegram bot token and chat id according to modules/tg-notify
    # cd secrets && EDITOR=nano nix --experimental-features 'nix-command flakes' run github:ryantm/agenix -- -e tgNotifyCredentials.age
  };
}
