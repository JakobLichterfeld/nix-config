{ lib, config, vars, pkgs, ... }:
{
  boot.initrd.kernelModules = [ "i915" ];
  hardware.cpu.intel.updateMicrocode = true;
  hardware.enableRedistributableFirmware = true;
  hardware.opengl.enable = true;
  hardware.opengl.driSupport = true;
  boot.zfs.forceImportRoot = true;
  zfs-root = {
    boot = {
      devNodes = "/dev/disk/by-id/";
      bootDevices = [  "nvme-FIKWOT_FN960_2TB_AA234330561" ];
      immutable = false;
      availableKernelModules = [  "uhci_hcd" "ehci_pci" "ahci" "sd_mod" ];
      removableEfi = true;
      kernelParams = [
      "consoleblank=60"
      ];
      sshUnlock = {
        enable = false;
        authorizedKeys = [ ];
      };
    };
    networking = {
      hostName = config.age.secrets.MainServer_hostName.path;
      timeZone = config.age.secrets.MainServer_timeZone.path;
      hostId = config.age.secrets.MainServer_hostId.path;
    };
  };

  imports = [
    ./filesystems
    ./shares ];

  powerManagement.powertop.enable = true;

  systemd.services.hd-idle = {
    description = "HD spin down daemon";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.hd-idle}/bin/hd-idle -i 900";
    };
  };

  networking = {
  nameservers = config.age.secrets.MainServer_nameservers.path;
  defaultGateway = config.age.secrets.MainServer_defaultGateway.path;
  interfaces = {
    enp1s0.ipv4 = {
      addresses = [{
        address = config.age.secrets.MainServer_ipAddress.path;
        prefixLength = 24;
      }];
    };
    enp2s0.ipv4 = {
      addresses = [{
        address = config.age.secrets.MainServer_ipAddress2.path;
        prefixLength = 24;
      }];
    };
  };
};

  networking.firewall.allowedTCPPorts = [
    5201 # iperf3
  ];

  virtualisation.docker.storageDriver = "overlay2";

  systemd.services.mergerfs-uncache.serviceConfig.ExecStart = lib.mkForce "/run/current-system/sw/bin/mergerfs-uncache -s ${vars.cacheArray} -d ${vars.slowerArray} -t 50";

  services.prometheus = {
    enable = true;
    exporters = {
      node = {
        enable = true;
        openFirewall = true;
        enabledCollectors = [ "systemd" "zfs" "smartctl" "collectd" ];
      };
    };
  };


  environment.systemPackages = with pkgs; [
    pciutils # A collection of programs for inspecting and manipulating configuration of PCI devices
    glances # Cross-platform curses-based monitoring tool
    hdparm # A tool to get/set ATA/SATA drive parameters under Linux
    hd-idle # Spins down external disks after a period of idle time
    hddtemp # Tool for displaying hard disk temperature
    smartmontools # Tools for monitoring the health of hard drives
    powertop # Analyze power consumption on Intel-based laptops
    cpufrequtils # Tools to display or change the CPU governor settings
    gnumake
    gcc
  ];
  }
