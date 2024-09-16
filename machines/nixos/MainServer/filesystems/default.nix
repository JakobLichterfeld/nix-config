{
  inputs,
  config,
  lib,
  vars,
  pkgs,
  ...
}:
{

  imports = [
    ./snapraid.nix
  ];

  services.zfs = {
    autoScrub.enable = true;
    zed.settings = {
      ZED_DEBUG_LOG = "/tmp/zed.debug.log";
      ZED_EMAIL_ADDR = [ "noreply" ];
      ZED_EMAIL_PROG = "/run/current-system/sw/bin/notify";
      ZED_EMAIL_OPTS = "-t '@SUBJECT@' -m";

      ZED_NOTIFY_INTERVAL_SECS = 3600;
      ZED_NOTIFY_VERBOSE = true;

      ZED_USE_ENCLOSURE_LEDS = true;
      ZED_SCRUB_AFTER_RESILVER = true;
    };
    zed.enableMail = false;
  };

  programs.fuse.userAllowOther = true;

  environment.systemPackages = with pkgs; [
    gptfdisk
    xfsprogs
    parted
    snapraid
    mergerfs
    mergerfs-tools
  ];

  boot.initrd.systemd.enable = true; # enable systemd in initrd

  fileSystems."/" = lib.mkForce {
    device = "rpool/nixos/empty";
    fsType = "zfs";
  };

  boot.initrd.systemd.services.rollback = {
    description = "Rollback root filesystem to a pristine state on boot";
    wantedBy = [
      "initrd.target"
    ];
    after = [
      "zfs-import-rpool.service"
    ];
    before = [
      "sysroot.mount"
    ];
    path = with pkgs; [
      zfs
    ];
    unitConfig.DefaultDependencies = "no";
    serviceConfig.Type = "oneshot";
    script = ''
      zfs rollback -r rpool/nixos/empty@start && echo "  >> >> rollback complete << <<"
    '';
  };

  fileSystems."/nix" = lib.mkForce {
    device = "rpool/nixos/nix";
    fsType = "zfs";
    neededForBoot = true;
  };

  fileSystems."/etc/nixos" = lib.mkForce {
    device = "rpool/nixos/config";
    fsType = "zfs";
    neededForBoot = true;
  };

  fileSystems."/boot" = lib.mkForce {
    device = "bpool/nixos/root";
    fsType = "zfs";
  };

  fileSystems."/home" = lib.mkForce {
    device = "rpool/nixos/home";
    fsType = "zfs";
    neededForBoot = true;
  };

  fileSystems."/persist" = lib.mkForce {
    device = "rpool/nixos/persist";
    fsType = "zfs";
    neededForBoot = true;
  };

  fileSystems."/var/log" = lib.mkForce {
    device = "rpool/nixos/var/log";
    fsType = "zfs";
  };

  fileSystems."/var/lib/containers" = lib.mkForce {
    device = "/dev/zvol/rpool/docker";
    fsType = "ext4";
  };

  fileSystems.${vars.cacheArray} = lib.mkForce {
    device = "cachepool/cache";
    fsType = "zfs";
  };

  fileSystems."/mnt/data1" = {
    device = "/dev/disk/by-label/Data1";
    fsType = "xfs";
  };

  fileSystems."/mnt/parity1" = {
    device = "/dev/disk/by-label/Parity1";
    fsType = "xfs";
  };

  fileSystems.${vars.slowerArray} = {
    device = "/mnt/data*";
    options = [
      "defaults"
      "allow_other"
      "moveonenospc=1"
      "minfreespace=50G"
      "func.getattr=newest"
      "fsname=mergerfs_slower"
      "uid=994"
      "gid=993"
      "umask=002"
      "x-mount.mkdir"
    ];
    fsType = "fuse.mergerfs";
  };

  fileSystems.${vars.mainArray} = {
    device = "${vars.cacheArray}:${vars.slowerArray}";
    options = [
      "category.create=epff"
      "defaults"
      "allow_other"
      "moveonenospc=1"
      "minfreespace=100G"
      "func.getattr=newest"
      "fsname=user"
      "uid=994"
      "gid=993"
      "umask=002"
      "x-mount.mkdir"
    ];
    fsType = "fuse.mergerfs";
  };

  services.smartd = {
    enable = true;
    defaults.autodetected = "-a -o on -S on -s (S/../.././02|L/../../6/03) -n standby,q";
    notifications = {
      wall = {
        enable = true;
      };
      mail = {
        enable = false;
        sender = config.email.fromAddress;
        recipient = config.email.toAddress;
      };
    };
  };

}
