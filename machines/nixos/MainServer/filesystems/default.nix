{
  config,
  lib,
  pkgs,
  ...
}:
let
  hl = config.homelab;
in
{

  imports = [
    ./snapraid.nix
  ];

  programs.fuse.userAllowOther = true; # Allow non-root users to specify the allow_other or allow_root mount options

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

  fileSystems.${hl.mounts.fast} = {
    device = "cachepool/cache";
    fsType = "zfs";
    options = [
      "zfsutil"
      "x-mount.mkdir"
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

  fileSystems.${hl.mounts.slower} = {
    device = "/mnt/data*";
    options = [
      "defaults"
      "allow_other"
      "moveonenospc=1"
      "minfreespace=50G"
      "func.getattr=newest"
      "fsname=mergerfs_slower"
      # "uid=994" # commented out, as we want to preserve POSIX rights
      # "gid=993" # commented out, as we want to preserve POSIX rights
      "umask=002"
      "x-mount.mkdir"
    ];
    fsType = "fuse.mergerfs";
  };

  fileSystems.${hl.mounts.merged} = {
    device = "${hl.mounts.fast}:${hl.mounts.slower}";
    options = [
      "category.create=epff"
      "defaults"
      "allow_other"
      "moveonenospc=1"
      "minfreespace=100G"
      "func.getattr=newest"
      "fsname=user"
      # "uid=994" # commented out, as we want to preserve POSIX rights
      # "gid=993" # commented out, as we want to preserve POSIX rights
      "umask=002"
      "x-mount.mkdir"
    ];
    fsType = "fuse.mergerfs";
  };

  services.smartd = {
    enable = !config.services.prometheus.exporters.smartctl.enable;
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
