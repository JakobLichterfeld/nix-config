{
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

  programs.fuse.userAllowOther = true;

  environment.systemPackages = with pkgs; [
    gptfdisk
    xfsprogs
    parted
    snapraid
    mergerfs
    mergerfs-tools
  ];

  # This fixes the weird mergerfs permissions issue
  boot.initrd.systemd.enable = true;

  fileSystems.${vars.cacheArray} = {
    device = "cachepool/cache";
    fsType = "zfs";
    options = [
      "zfsutil"
      "x-systemd.requires=zfs-import-cache.service"
      "x-systemd.after=zfs-import-cache.service"
      "x-systemd.after=zfs-mount.service"
    ];
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
    enable = !lib.hasAttr "smartctl" config.services.prometheus.exporters;
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
