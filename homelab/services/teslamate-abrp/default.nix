{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  service = "teslamate-abrp";
  cfg = config.homelab.services.teslamate-abrp;
  homelab = config.homelab;
  teslamate-abrp-image = "fetzu/teslamate-abrp";
  teslamate-abrp-version = "4.0.2";
  # Digest and hash of the image, both change with the version. To get them, run this
  # in the repository with VERSION replaced and copy imageDigest and hash from its output:
  # nix run --inputs-from . nixpkgs#nix-prefetch-docker -- --image-name fetzu/teslamate-abrp --image-tag VERSION --os linux --arch amd64
  teslamate-abrp-image-digest = "sha256:b5eb07fbaf9887d035b0a5b44b16d7d45115028c173edae2b3f4391fdfed84a4";
  teslamate-abrp-image-hash = "sha256-cac3YEo3etbHr0z3oRTB6/HEeeMEgyqarvzJnnB17JQ=";
in
{
  options.homelab.services.${service} = {
    enable = lib.mkEnableOption {
      description = "Enable ${service}";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.homelab.services.teslamate.enable;
        message = "${service} cannot be enabled when teslamate is not enabled.";
      }
      {
        assertion = config.services.mosquitto.enable;
        message = "${service} cannot be enabled when mosquitto is not enabled.";
      }
    ];

    virtualisation = {
      podman.enable = true;
      oci-containers = {
        containers = {
          teslamate-abrp = {
            image = "${teslamate-abrp-image}:${teslamate-abrp-version}";
            # Part of the build: a version bump downloads the image while the old
            # container keeps running, a failed download stops nothing.
            imageFile = pkgs.dockerTools.pullImage {
              imageName = teslamate-abrp-image;
              imageDigest = teslamate-abrp-image-digest;
              hash = teslamate-abrp-image-hash;
              finalImageTag = teslamate-abrp-version;
            };
            autoStart = true;
            environmentFiles = [ config.age.secrets.teslamateEnvABRP.path ];
            environment = {
              MQTT_SERVER = "host.containers.internal";
              MQTT_PORT = "${toString config.homelab.services.teslamate.mqtt.listenPort}";
            };
            extraOptions = lib.optional (
              !config.virtualisation.podman.defaultNetwork.settings.dns_enabled
            ) "--add-host=host.containers.internal:10.88.0.1";
          };
        };
      };
    };
    systemd.services."podman-${service}" = {
      after = [
        "network-online.target"
        "mosquitto.service"
        "teslamate.service"
        "nss-lookup.target"
      ];
      requires = [
        "mosquitto.service"
        "teslamate.service"
      ];
      wants = [ "network-online.target" ];
    };
  };
}
