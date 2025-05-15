{ ... }:
{
  age.secrets.dnsApiCredentials = {
    file = ./dnsApiCredentials.age; # content is according to the provider, see https://go-acme.github.io/lego/dns/
    # cd secrets && EDITOR=nano nix --experimental-features 'nix-command flakes' run github:ryantm/agenix -- -e dnsApiCredentials.age
  };

  age.secrets.hashedUserPassword = {
    file = ./hashedUserPassword.age; # content is result of: `mkpasswd -m sha-512`
    # cd secrets && EDITOR=nano nix --experimental-features 'nix-command flakes' run github:ryantm/agenix -- -e hashedUserPassword.age
  };

  age.secrets.sambaPassword = {
    file = ./sambaPassword.age; # content is the samba password
    # cd secrets && EDITOR=nano nix --experimental-features 'nix-command flakes' run github:ryantm/agenix -- -e sambaPassword.age
  };

  age.secrets.tailscaleAuthKey = {
    file = ./tailscaleAuthKey.age; # generate for max 90 day at https://login.tailscale.com/admin/settings/keys
    # cd secrets && EDITOR=nano nix --experimental-features 'nix-command flakes' run github:ryantm/agenix -- -e tailscaleAuthKey.age
  };

  age.secrets.teslamateEnv = {
    file = ./teslamateEnv.age; # content is the teslamate env file, so ENCRYPTION_KEY=, DATABASE_PASS=, RELEASE_COOKIE=, DATABASE_TIMEOUT= and TZ=
    # cd secrets && EDITOR=nano nix --experimental-features 'nix-command flakes' run github:ryantm/agenix -- -e teslamateEnv.age
  };

  age.secrets.teslamateEnvABRP = {
    file = ./teslamateEnvABRP.age; # content is the ABRP teslamate env file, so USER_TOKEN= , CAR_NUMBER= and CAR_MODEL=
    # cd secrets && EDITOR=nano nix --experimental-features 'nix-command flakes' run github:ryantm/agenix -- -e teslamateEnvABRP.age
  };

  age.secrets.tgNotifyCredentials = {
    file = ./tgNotifyCredentials.age; # content is the telegram bot token and chat id according to modules/tg-notify
    # cd secrets && EDITOR=nano nix --experimental-features 'nix-command flakes' run github:ryantm/agenix -- -e tgNotifyCredentials.age
  };
}
