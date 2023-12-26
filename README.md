# nix-config

Infrastructure as Code (IaC)

After using a shell script to automate my desktop Ubuntu installation from 2011 to 2023, I finally migrated the 2646 lines of code to Ansible, see <https://github.com/JakobLichterfeld/infra-playbook>

End of 2023 I migrated to Nix.

## MainDev (Mac)

Managed using `nix-darwin` and `home-manager`. Impure packages and apps are managed by `homebrew` and `mas`

## How to use

Update dependencies: `nix --experimental-features 'nix-command flakes' flake update`

build: `nix --experimental-features 'nix-command flakes' build .#darwinConfigurations."MainDev".system`

as macOS does not allow writing to `/` write to symlink:

```shell
printf 'run\tprivate/var/run\n' | sudo tee -a /etc/synthetic.conf # read below
/System/Library/Filesystems/apfs.fs/Contents/Resources/apfs.util -t # read below
```

apply changes: `./result/sw/bin/darwin-rebuild switch --flake .`

## Contributing

All contributions are welcome and greatly appreciated!

## Disclaimer

The Flake is primarily designed for personal use, so it is subject to frequent modifications and glitches. Use it at your own risk and do not anticipate guidance for its installation on your device.
