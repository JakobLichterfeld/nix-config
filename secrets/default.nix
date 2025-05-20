{ ... }:
{
  age.secrets.deadmanPingEnvMainServer = {
    file = ./deadmanPingEnvMainServer.age; # content is the deadman ping env file, with PING_URL= according to modules/deadman-ping
    # cd secrets && EDITOR=nano nix --experimental-features 'nix-command flakes' run github:ryantm/agenix -- -e deadmanPingUrl.age
  };

  age.secrets.dnsApiCredentials = {
    file = ./dnsApiCredentials.age; # content is according to the provider, see https://go-acme.github.io/lego/dns/
    # cd secrets && EDITOR=nano nix --experimental-features 'nix-command flakes' run github:ryantm/agenix -- -e dnsApiCredentials.age
  };

  age.secrets.hashedUserPassword = {
    file = ./hashedUserPassword.age; # content is result of: `mkpasswd -m sha-512`
    # cd secrets && EDITOR=nano nix --experimental-features 'nix-command flakes' run github:ryantm/agenix -- -e hashedUserPassword.age
  };

  age.secrets.resticPassword = {
    file = ./resticPassword.age; # content is the restic password
    # cd secrets && EDITOR=nano nix --experimental-features 'nix-command flakes' run github:ryantm/agenix -- -e resticPassword.age
  };

  age.secrets.s3StorageEnv = {
    file = ./s3StorageEnv.age; # content is the s3 storage env file, so AWS_DEFAULT_REGION=, AWS_ACCESS_KEY_ID= and AWS_SECRET_ACCESS_KEY=
    # cd secrets && EDITOR=nano nix --experimental-features 'nix-command flakes' run github:ryantm/agenix -- -e s3StorageEnv.age
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

  age.secrets.teslamateEnvTelegramBot = {
    file = ./teslamateEnvTelegramBot.age; # content is the Teslamate Telegram Bot env file, so TELEGRAM_BOT_API_KEY= and TELEGRAM_BOT_CHAT_ID=
    # cd secrets && EDITOR=nano nix --experimental-features 'nix-command flakes' run github:ryantm/agenix -- -e teslamateEnvABRP.age
  };

  age.secrets.tgNotifyCredentials = {
    file = ./tgNotifyCredentials.age; # content is the telegram bot token and chat id according to modules/tg-notify
    # cd secrets && EDITOR=nano nix --experimental-features 'nix-command flakes' run github:ryantm/agenix -- -e tgNotifyCredentials.age
  };
}
