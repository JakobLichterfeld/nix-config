{
  config,
  pkgs,
  lib,
  ...
}:
{
  age.secrets.tailscaleAuthKey.file = ../../secrets/tailscaleAuthKey.age; # generate for max 90 day at https://login.tailscale.com/admin/settings/keys
  # cd secrets && EDITOR=nano nix --experimental-features 'nix-command flakes' run github:ryantm/agenix -- -e tailscaleAuthKey.age

  environment.systemPackages = [ pkgs.tailscale ];

  networking.firewall.trustedInterfaces = [ "tailscale0" ];
  networking.firewall.allowedUDPPorts = [ config.services.tailscale.port ];

  services.tailscale = {
    enable = true;
    authKeyFile = config.age.secrets.tailscaleAuthKey.path;
  };
}
