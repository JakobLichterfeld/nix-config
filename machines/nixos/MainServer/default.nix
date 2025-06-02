{
  config,
  lib,
  pkgs,
  vars,
  machinesSensitiveVars,
  ...
}:
{
  age.identityPaths = [ "/persist/ssh/id_ed25519_main_server" ];

  nixpkgs.config.packageOverrides = pkgs: {
    vaapiIntel = pkgs.vaapiIntel.override { enableHybridCodec = true; };
  };
  hardware = {
    enableRedistributableFirmware = true;
    cpu.intel.updateMicrocode = true;
    graphics = {
      enable = true;
      extraPackages = with pkgs; [
        intel-media-driver
        intel-vaapi-driver
        vaapiVdpau
        intel-compute-runtime # OpenCL filter support (hardware tonemapping and subtitle burn-in)
        vpl-gpu-rt # QSV on 11th gen or newer
      ];
    };
  };
  boot = {
    zfs.forceImportRoot = true;
    kernelParams = [
      "consoleblank=60"
      "acpi_enforce_resources=lax"
    ];
    kernelModules = [
      "kvm-intel"
      "coretemp" # for CPU temperature sensors
      "jc42"
      "lm78"
      "xhci_pci"
      "ahci" # for SATA drives
      "nvme" # for NVMe drives
      "usb_storage" # for USB drives
      "r8169" # for the Realtek network card
      "sd_mod"
      "i2c_i801" # for i2c sensors
    ];
    blacklistedKernelModules = [
      #"i915" # disable the graphics driver, as it is a headless server, commenting out for HW decoding
      "snd_hda_intel" # disable the onboard audio driver, as it is a headless server
      "snd_sof_pci_intel_tgl" # disable the onboard audio driver, as it is a headless server
      "mei_me" # disable the Intel Management Engine driver, as it is not needed
      "mei" # disable the Intel Management Engine driver, as it is not needed
    ];
  };
  networking = {
    useDHCP = false; # we use static IPs
    networkmanager.enable = false;
    hostName = machinesSensitiveVars.MainServer.hostName;
    interfaces = {
      enp1s0 = {
        ipv4.addresses = [
          {
            address = machinesSensitiveVars.MainServer.ipAddress;
            prefixLength = 24;
          }
        ];
      };
      enp2s0 = {
        ipv4.addresses = [
          {
            address = machinesSensitiveVars.MainServer.ipAddress2;
            prefixLength = 24;
          }
        ];
      };
    };
    nameservers = [ machinesSensitiveVars.MainServer.nameservers ];
    defaultGateway = {
      address = machinesSensitiveVars.MainServer.defaultGateway;
      interface = "enp1s0";
    };
    hostId = machinesSensitiveVars.MainServer.hostId;
    firewall = {
      enable = true;
      allowPing = true;
      trustedInterfaces = [
        "enp1s0"
        "enp2s0"
        "tailscale0"
      ];
    };
  };
  zfs-root = {
    boot = {
      partitionScheme = {
        biosBoot = "-part1";
        efiBoot = "-part3";
        swap = "-part5";
        bootPool = "-part2";
        rootPool = "-part4";
        cachePool = "-part6";
      };
      bootDevices = [ "nvme-FIKWOT_FN960_2TB_AA234330561" ];
      immutable = true;
      availableKernelModules = [
        "xhci_pci"
        "ahci"
        "nvme"
        "usb_storage"
        "sd_mod"
      ];
      removableEfi = true;
    };
  };
  imports = [
    ./filesystems
    #./backup
    ./homelab
  ];

  virtualisation.docker.storageDriver = "overlay2";

  services.mover = {
    enable = true;
    cacheArray = vars.cacheArray;
    backingArray = vars.slowerArray;
    user = config.homelab.user;
    group = config.homelab.group;
    percentageFree = 60;
    excludedPaths = [
      ".DS_Store"
      ".cache"
    ];
  };

  powerManagement = {
    enable = true;
    cpuFreqGovernor = "powersave";
    powertop.enable = false;
  };

  environment.systemPackages = with pkgs; [
    pciutils # A collection of programs for inspecting and manipulating configuration of PCI devices
    glances # Cross-platform curses-based monitoring tool
    hdparm # A tool to get/set ATA/SATA drive parameters under Linux
    hd-idle # Spins down external disks after a period of idle time
    hddtemp # Tool for displaying hard disk temperature
    smartmontools # Tools for monitoring the health of hard drives
    cpufrequtils # Tools to display or change the CPU governor settings
    gnumake
    gcc
    intel-gpu-tools # Tools for debugging the Intel graphics driver
    powertop # Analyze power consumption on Intel-based laptops
    nvme-cli # Command line interface for NVMe devices
  ];

  services.deadman-ping = {
    enable = true;
    credentialsFile = config.age.secrets.deadmanPingEnvMainServer.path;
  };

  tg-notify = {
    enable = true;
    credentialsFile = config.age.secrets.telegramCredentials.path;
  };

}
