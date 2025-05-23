<!-- markdownlint-disable MD033 -->

# nix-config

Infrastructure as Code (IaC)

After using a shell script to automate my desktop Ubuntu installation from 2011 to 2023, I finally migrated the 2646 lines of code to Ansible, see <https://github.com/JakobLichterfeld/infra-playbook>

End of 2023 I migrated to Nix.

## MainServer (Intel N100)

[Hardware documentation](machines/nixos/MainServer/HARDWARE.md) | [System design documentation](machines/nixos/MainServer/design.md)

<details><summary>Installation process</summary><p>

Download [NixOS minimal ISO image](https://channels.nixos.org/nixos-25.05/latest-nixos-minimal-x86_64-linux.iso) copy it to a USB stick, using USBImager for example, see [creating bootable USB flash drive with a graphical tool](https://nixos.org/manual/nixos/stable/#sec-booting-from-usb).

Boot into the NixOS live environment (F11 for boot menu)

Create a root password using the TTY

```bash
sudo su
passwd
```

From your host, copy the public SSH key to the server

```bash
ssh-add ~/.ssh/id_ed25519
ssh-copy-id -i ~/.ssh/id_ed25519 root@nixos_installation_ip
```

SSH into the host with agent forwarding enabled

```bash
ssh -A root@nixos_installation_ip
```

Enable Nix Flakes functionality

```bash
mkdir -p ~/.config/nix
echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf
```

Partition and mount the drives using [disko](https://github.com/nix-community/disko) (declarative disk partitioning and formatting using nix)

```bash
curl https://raw.githubusercontent.com/JakobLichterfeld/nix-config/main/machines/nixos/MainServer/filesystems/disko.nix \
    -o /tmp/disko.nix
nix --experimental-features "nix-command flakes" run github:nix-community/disko \
    -- --mode destroy,format,mount /tmp/disko.nix
```

Install programs needed for system installation

```bash
nix-env -f '<nixpkgs>' -iA git
nix-env -f '<nixpkgs>' -iA git-crypt
```

Clone this repository

```bash
mkdir -p /mnt/etc/nixos
git clone https://github.com/JakobLichterfeld/nix-config.git /mnt/etc/nixos
```

Put the private and GPG key into place (required for secret management)

```bash
mkdir -p /mnt/persist/ssh
exit
scp ~/.ssh/id_ed25519_main_server root@nixos_installation_ip:/mnt/persist/ssh/id_ed25519_main_server
scp ~/.ssh/nix-config_local.key.asc root@nixos_installation_ip:/mnt/persist/ssh/nix-config_local.key.asc
ssh -A nixos@nixos_installation_ip
chmod 700 /mnt/persist/ssh
chmod 600 /mnt/persist/ssh/*
```

Unlock the git-crypt vault

```bash
cd /mnt/etc/nixos
chown -R root:root .
git-crypt unlock /mnt/persist/ssh/nix-config_local.key.asc
```

Install system

```bash
nixos-install \
--root "/mnt" \
--no-root-passwd \
--flake "git+file:///mnt/etc/nixos#MainServer"
```

Unmount the filesystems

```bash
umount /mnt/boot/efis/nvme-FIKWOT_FN960_2TB_AA234330561-part3/
umount -Rl "/mnt"
cd /
zpool export -a
```

Remove the installation media

Reboot

```bash
reboot
```

</p></details>

<details><summary>Update to newest config</summary><p>

```bash
sudo su
cd /etc/nixos
git pull
nixos-rebuild switch --flake /etc/nixos#MainServer
```

or use the flake command

```bash
nix --experimental-features 'nix-command flakes' run .#pullAndSwitch
```

</p></details>

## MainDev (Mac)

Managed by `nix-darwin` and `home-manager`. Impure packages and applications are managed by `homebrew` and `mas`.

<details><summary>Installation process</summary><p>

[Make sure nix is installed](https://nixos.org/download#nix-install-macos)

Enable Rosetta to build x86 binaries with Apple Silicon: `softwareupdate --install-rosetta --agree-to-license`

Update dependencies and install: `nix --experimental-features 'nix-command flakes' run .#updateDependenciesAndSwitch`

or

build: `nix --experimental-features 'nix-command flakes' build .#darwinConfigurations."MainDev".system`

install: `nix run nix-darwin -- switch --flake .#MainDev`

apply changes: `sudo darwin-rebuild switch --flake .#MainDev`

</p></details>

## Contributing

All contributions are welcome and greatly appreciated!

## Disclaimer

The Flake is primarily designed for personal use, so it is subject to frequent modifications and glitches. Use it at your own risk and do not anticipate guidance for its installation on your device.
