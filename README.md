# nix-config

Infrastructure as Code (IaC)

After using a shell script to automate my desktop Ubuntu installation from 2011 to 2023, I finally migrated the 2646 lines of code to Ansible, see <https://github.com/JakobLichterfeld/infra-playbook>

End of 2023 I migrated to Nix.

## MainDev (Mac)

Managed by `nix-darwin` and `home-manager`. Impure packages and applications are managed by `homebrew` and `mas`.

## MainServer

<details><summary>Installation process</summary><p>
According to [ne9z's "NixOS Root on ZFS"](https://openzfs.github.io/openzfs-docs/Getting%20Started/NixOS/Root%20on%20ZFS.html)

Elevate privileges, declare target disk array variable, the mountpoint variable, swap size variable and reserved space variable
```bash
sudo su

DISK='/dev/disk/by-id/nvme-FIKWOT_FN960_2TB_AA234330561'
MNT=$(mktemp -d)
RESERVE=1
```

Enable Nix Flakes functionality
```bash
mkdir -p ~/.config/nix
echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf
```

Install programs needed for system installation
```bash
if ! command -v git; then nix-env -f '<nixpkgs>' -iA git; fi
if ! command -v jq;  then nix-env -f '<nixpkgs>' -iA jq; fi
if ! command -v partprobe;  then nix-env -f '<nixpkgs>' -iA parted; fi
if ! command -v git-crypt;  then nix-env -f '<nixpkgs>' -iA git-crypt; fi
```

Partition the drive
```bash
partition_disk () {
 local disk="${1}"
 blkdiscard -f "${disk}" || true

 parted --script --align=optimal  "${disk}" -- \
 mklabel gpt \
 mkpart EFI 2MiB 1GiB \
 mkpart bpool 1GiB 5GiB \
 mkpart rpool 5GiB 261GiB \
 mkpart swap 261GiB 265GiB \
 mkpart cache 265GiB -$((RESERVE))GiB \
 mkpart BIOS 1MiB 2MiB \
 set 1 esp on \
 set 6 bios_grub on \
 set 6 legacy_boot on

 partprobe "${disk}"
 udevadm settle
}

for i in ${DISK}; do
   partition_disk "${i}"
done
```

Setup swap
```bash
for i in ${DISK}; do
   mkswap -L "swap" "${i}"-part4
   swapon "${i}"-part4
done
```

Create boot pool
```bash
zpool create \
    -o compatibility=grub2 \
    -o ashift=12 \
    -o autotrim=on \
    -O acltype=posixacl \
    -O canmount=off \
    -O devices=off \
    -O compression=lz4 \
    -O normalization=formD \
    -O relatime=on \
    -O xattr=sa \
    -O mountpoint=/boot \
    -R "${MNT}" \
    bpool \
    $(for i in ${DISK}; do
       printf '%s ' "${i}-part2";
      done)
```

Create root pool
```bash
zpool create \
    -o ashift=12 \
    -o autotrim=on \
    -R "${MNT}" \
    -O acltype=posixacl \
    -O canmount=off \
    -O compression=zstd \
    -O dnodesize=auto \
    -O normalization=formD \
    -O relatime=on \
    -O xattr=sa \
    -O mountpoint=/ \
    rpool \
   $(for i in ${DISK}; do
      printf '%s ' "${i}-part3";
     done)
```

Create cache pool
```bash
zpool create \
    -o ashift=12 \
    -o autotrim=on \
    -R "${MNT}" \
    -O acltype=posixacl \
    -O canmount=off \
    -O compression=zstd \
    -O dnodesize=auto \
    -O normalization=formD \
    -O relatime=on \
    -O xattr=sa \
    -O mountpoint=/mnt/cache \
    cachepool \
   $(for i in ${DISK}; do
      printf '%s ' "${i}-part5";
     done)
```

Create root system container
```bash
zfs create \
 -o canmount=off \
 -o mountpoint=none \
rpool/nixos
```

Create the system datasets and manage mountpoints
```bash
zfs create -o mountpoint=legacy     rpool/nixos/root
mount -t zfs rpool/nixos/root "${MNT}"/

zfs create -o mountpoint=legacy rpool/nixos/home
mkdir "${MNT}"/home
mount -t zfs rpool/nixos/home "${MNT}"/home

zfs create -o mountpoint=none   rpool/nixos/var
zfs create -o mountpoint=legacy rpool/nixos/var/lib
zfs create -o mountpoint=legacy rpool/nixos/var/log
zfs create -o mountpoint=legacy rpool/nixos/config
zfs create -o mountpoint=legacy rpool/nixos/persist
zfs create -o mountpoint=legacy rpool/nixos/nix

zfs create -o mountpoint=none bpool/nixos
zfs create -o mountpoint=legacy bpool/nixos/root
mkdir "${MNT}"/boot
mount -t zfs bpool/nixos/root "${MNT}"/boot

mkdir -p "${MNT}"/var/log
mkdir -p "${MNT}"/var/lib
mkdir -p "${MNT}"/etc/nixos
mkdir -p "${MNT}"/nix
mkdir -p "${MNT}"/persist

mount -t zfs rpool/nixos/var/lib "${MNT}"/var/lib
mount -t zfs rpool/nixos/var/log "${MNT}"/var/log
mount -t zfs rpool/nixos/config "${MNT}"/etc/nixos
mount -t zfs rpool/nixos/nix "${MNT}"/nix
mount -t zfs rpool/nixos/persist "${MNT}"/persist
zfs create -o mountpoint=legacy rpool/nixos/empty
zfs snapshot rpool/nixos/empty@start
```

Format and mount ESP
```bash
for i in ${DISK}; do
 mkfs.vfat -n EFI "${i}"-part1
 mkdir -p "${MNT}"/boot/efis/"${i##*/}"-part1
 mount -t vfat -o iocharset=iso8859-1 "${i}"-part1 "${MNT}"/boot/efis/"${i##*/}"-part1
done
```

Clone this repository
```bash
git clone https://github.com/JakobLichterfeld/nix-config.git "${MNT}"/etc/nixos
```

Put the private key into place (required for secret management)
```bash
mkdir -p "${MNT}"/persist/ssh
echo "${MNT}"
exit
scp ~/.ssh/id_ed25519_main_server root@nixos_installation_ip:/MNT_path_see_echo_from_above/persist/ssh/id_ed25519_main_server
scp ~/.ssh/nix-config_local.key.asc root@nixos_installation_ip:/MNT_path_see_echo_from_above/etc/nixos/nix-config_local.key.asc
ssh nixos@nixos_installation_ip
chmod 700 "${MNT}"/persist/ssh
chmod 600 "${MNT}"/persist/ssh/id_ed25519_main_server
cd "${MNT}"/etc/nixos
git-crypt unlock nix-config_local.key.asc
```

Create Home Dir
```bash
mkdir -p /home/jakob
```


Install system and apply configuration
```bash
nixos-install \
--root "${MNT}" \
--no-root-passwd \
--flake "git+file://${MNT}/etc/nixos#MainServer"
```

Unmount the filesystems
```bash
umount -Rl "${MNT}"
cd /
zpool export -a
```

Reboot
```bash
reboot
```
</p></details>

<details><summary>Update to newest config</summary><p>

```bash
cd /etc/nixos
git pull
nixos-rebuild switch --flake /etc/nixos#MainServer
```

</p></details>

## How to use

[Make sure nix is installed](https://nixos.org/download#nix-install-macos)

[install nix-darwin](https://github.com/LnL7/nix-darwin?tab=readme-ov-file#flakes)

[install home-manager](https://nix-community.github.io/home-manager/index.xhtml#sec-install-standalone)

Update dependencies: `nix --experimental-features 'nix-command flakes' flake update`

build: `nix --experimental-features 'nix-command flakes' build .#darwinConfigurations."MainDev".system`

apply: `darwin-rebuild switch  --flake .`

as macOS does not allow writing to `/` write to symlink:

```shell
printf 'run\tprivate/var/run\n' | sudo tee -a /etc/synthetic.conf
/System/Library/Filesystems/apfs.fs/Contents/Resources/apfs.util -t
```

apply changes: `./result/sw/bin/darwin-rebuild switch --flake .`

## Contributing

All contributions are welcome and greatly appreciated!

## Disclaimer

The Flake is primarily designed for personal use, so it is subject to frequent modifications and glitches. Use it at your own risk and do not anticipate guidance for its installation on your device.
