{ lib, config, vars, pkgs, machinesSensitiveVars,... }:
{
  age.identityPaths = ["/persist/ssh/id_ed25519_main_server"];

  boot.initrd.kernelModules = [ "xhci_pci" "ahci" "nvme" "usb_storage" "sd_mod" ];
  hardware.cpu.intel.updateMicrocode = true;
  hardware.enableRedistributableFirmware = true;
  hardware.opengl.enable = true;
  hardware.opengl.driSupport = true;
  boot.zfs.forceImportRoot = true;
  zfs-root = {
    boot = {
      devNodes = "/dev/disk/by-id/";
      bootDevices = [  "nvme-FIKWOT_FN960_2TB_AA234330561" ];
      immutable.enable = true;
      removableEfi = true;
      sshUnlock = {
        enable = false;
        authorizedKeys = [ ];
      };
    };
  };
  boot.initrd.availableKernelModules = [ "xhci_pci" "ahci" "nvme" "usb_storage" "sd_mod" ];
  boot.kernelParams = [ "consoleblank=60" ];
  networking = {
    hostName = machinesSensitiveVars.MainServer.hostName;
    hostId = machinesSensitiveVars.MainServer.hostId;
    firewall.enable = true;
  };
  time.timeZone = "Europe/Berlin";


  imports = [
    ./filesystems
    ./shares ];

  powerManagement.powertop.enable = false;

  systemd.enableEmergencyMode = false; # as we have no console of any kind attached to the server, we don't want to end up in emergency mode

  systemd.services.hd-idle = {
    description = "HD spin down daemon";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.hd-idle}/bin/hd-idle -i 900";
    };
  };

  networking = {
  nameservers = [ machinesSensitiveVars.MainServer.nameservers ];
  defaultGateway = machinesSensitiveVars.MainServer.defaultGateway;
  interfaces = {
    enp1s0.ipv4 = {
      addresses = [{
        address = machinesSensitiveVars.MainServer.ipAddress;
        prefixLength = 24;
      }];
    };
    enp2s0.ipv4 = {
      addresses = [{
        address = machinesSensitiveVars.MainServer.ipAddress2;
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
