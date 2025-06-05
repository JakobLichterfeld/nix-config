# System Design — MainServer (Intel N100)

This document explains the architectural decisions, storage layout, and service structure of the MainServer.

## Goals

- Stable, declarative, and reproducible system via [NixOS](https://nixos.org)
- Safe storage with offline redundancy using [SnapRAID](https://www.snapraid.it/)
- High performance for active writes via a local NVMe cache
- System and data separation for fault tolerance

## Storage Layout

| Drive                          | Type | Usage                                     |
| ------------------------------ | ---- | ----------------------------------------- |
| NVMe (2 TB - FIKWOT FN960 2TB) | ZFS  | `rpool`, `bpool`, `swap`, and `cachepool` |
| mSATA SSD (2 TB)               | XFS  | SnapRAID data disk (`/mnt/data1`)         |
| SATA SSD (2 TB)                | XFS  | SnapRAID parity disk (`/mnt/parity1`)     |

### ZFS Pools

- `rpool`: ZFS root filesystem (`/`)
- `bpool`: Boot pool (separate for GRUB compatibility)
- `cachepool`: Used as a write cache

### Swap

Swap is defined as a 4 GB ZFS volume on the NVMe. Sufficient due to 32 GB RAM, but active for safety.

## SnapRAID Setup

- One data disk (`/mnt/data1`)
- One parity disk (`/mnt/parity1`)
- `content` files [exist on both disk](./filesystems/snapraid.nix) for redundancy
- Scheduled `sync` and `scrub` [via systemd timers](../_common/filesystems/snapraid.nix)
- Backup targets (e.g. DB dumps) are written to SnapRAID-managed disks

## MergerFS + Cache Workflow

- **Cache layer** on NVMe `/mnt/cache`
- **Media/data layer** on `/mnt/data1`
- Exposed merged view via MergerFS (`/mnt/user`)
- [`mergerfs-uncache.py`](../../../modules/mover/mergerfs-uncache.py) periodically moves files from cache to data
- Runs daily, with systemd integration and error notification via [`tg-notify`](../../../modules/tg-notify/default.nix)

## Security and Secrets

- SSH private keys are placed under `/persist`
- GPG key used to unlock git-crypt for secret management
- Root filesystem is immutable and declarative

## Update Strategy

- `flake.lock` is updated on the development machine (MainDev)
- Server performs manual `git pull` + `nixos-rebuild`
- Optional helper via `nix run .#pullAndSwitch`

## Why the NVMe is not part of SnapRAID

Even though the NVMe offers 2 TB capacity, it is excluded from the SnapRAID pool because:

- It holds the root ZFS system and must remain safe and cleanly managed
- SnapRAID expects disks to remain mostly static, which conflicts with system duties
- Risk of accidental loss is higher when mixing system and data redundancy
- Better to isolate it as high-performance cache and rely on backups for system recovery

---

## Monitoring Overview

The following diagram summarizes the Prometheus-based monitoring setup, including exporters and alerting flow:

```txt
+----------------+     scrapes     +----------------------------------------------------+
| Prometheus     | <-------------  | Exporter (node, mqtt, postgres, zfs, smartctl,...) |
|                |                 +----------------------------------------------------+
|                |                 +----------------------------------------------------+
|                | <-------------  | Blackbox Exporter                                  |
|                |                 +----------------------------------------------------+
|                |
|                | -- alerts -->   +----------------------------------------------------+
|                |                 | Alertmanager                                       |
+----------------+                 +--------+-------------------------------------------+
                                            |
                                            | Telegram
                                            ▼
                                   📱 Push notification on Mobile
```
