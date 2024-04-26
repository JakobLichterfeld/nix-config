{ config, pkgs, lib, ... }:
{
  age.secrets.tailscaleAuthKey.file = ../../secrets/tailscaleAuthKey.age; # generate for max 90 day at https://login.tailscale.com/admin/settings/keys
  # cd secrets && EDITOR=nano nix --experimental-features 'nix-command flakes' run github:ryantm/agenix -- -e tailscaleAuthKey.age

  environment.systemPackages = [ pkgs.tailscale ];

  networking.firewall.trustedInterfaces = [ "tailscale0" ];
  networking.firewall.allowedUDPPorts = [ config.services.tailscale.port ];

  serviceConfig = {
    Type = "oneshot";
    LoadCredential = [
      "TAILSCALE_AUTH_KEY:${config.age.secrets.tailscaleAuthKey.path}"
    ];
  };

  systemd.services.tailscale-autoconnect = {
    description = "Automatic connection to Tailscale";

    after = [ "network-pre.target" "tailscale.service" ];
    wants = [ "network-pre.target" "tailscale.service" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig.Type = "oneshot";

    script = with pkgs; ''

      # wait for tailscaled to settle
      echo "Waiting for tailscale.service start completion ..."
      sleep 5
      # (as of tailscale 1.4 this should no longer be necessary, but I find it still is)

      # check if already authenticated
      echo "Checking if already authenticated to Tailscale ..."
      status="$(${tailscale}/bin/tailscale status -json | ${jq}/bin/jq -r .BackendState)"
      if [ $status = "Running" ]; then  # do nothing
      	echo "Already authenticated to Tailscale, exiting."
        exit 0
      fi

      echo "Authenticating with Tailscale ..."
      # --advertise-exit-node
      ${tailscale}/bin/tailscale up --reset --auth-key "$TAILSCALE_AUTH_KEY"
    '';
  };
}
