{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.nvme-thermal-management;
in
{
  options.services.nvme-thermal-management = {
    enable = lib.mkEnableOption "Enable NVMe thermal management thresholds";

    device = lib.mkOption {
      type = lib.types.str;
      default = "/dev/nvme0";
      description = "Path to the NVMe device to configure.";
    };

    thermalThresholdLower = lib.mkOption {
      type = lib.types.int;
      default = 52;
      description = "Thermal Management Temperature 1 in Celsius. Must be less than thermalThresholdUpper.";
    };

    thermalThresholdUpper = lib.mkOption {
      type = lib.types.int;
      default = 65;
      description = "Thermal Management Temperature 2 in Celsius. Must be greater than thermalThresholdLower.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = lib.strings.hasPrefix "/dev/" cfg.device;
        message = "services.nvme-thermal-management.device must be an absolute path starting with /dev/";
      }
      {
        assertion = cfg.thermalThresholdLower < cfg.thermalThresholdUpper;
        message = "services.nvme-thermal-management.thermalThresholdLower must be less than thermalThresholdUpper as per NVMe spec.";
      }
    ];

    environment.systemPackages = with pkgs; [
      nvme-cli
    ];

    # Set NVMe thermal management thresholds via systemd service
    # see https://discourse.nixos.org/t/psa-keep-nvme-storage-devices-from-getting-too-hot/35830/3
    systemd.services.nvme-thermal-management = {
      description = "Set NVMe thermal management thresholds for ${cfg.device} (thermalThresholdLower=${toString cfg.thermalThresholdLower}°C, thermalThresholdUpper=${toString cfg.thermalThresholdUpper}°C)";
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        # the lower and upper thermal throttle management temperatures
        # for explanation see:
        # https://nvmexpress.org/resource/technology-power-features/
        # The drive's firmware only supports thermal management thresholds within a specific, high range.
        # These values are read from 'nvme id-ctrl <device>' (mntmt and mxtmt fields).
        # To check supported range: sudo nvme id-ctrl /dev/nvme0
        #
        # https://nvmexpress.org/wp-content/uploads/NVM-Express-Base-Specification-2.0d-2024.01.11-Ratified.pdf
        # 5.27.1.13 Host Controlled Thermal Management (Feature Identifier 10h)
        # thermalThresholdLower (upper 16 bits), thermalThresholdUpper (lower 16 bits)
        # Combined value = (thermalThresholdLower_Kelvin << 16) | thermalThresholdUpper_Kelvin
        # Example: thermalThresholdLower=110C (383K), thermalThresholdUpper=118C (391K) -> (383 << 16) | 391 = 0x017F0187
        ExecStart = "${pkgs.bash}/bin/bash -c '${pkgs.nvme-cli}/bin/nvme set-feature ${cfg.device} -f 0x10 -V 0x$(printf %%08x $(( (${toString cfg.thermalThresholdLower} + 273) * 65536 + (${toString cfg.thermalThresholdUpper} + 273) )) )'";
      };
    };
  };
}
