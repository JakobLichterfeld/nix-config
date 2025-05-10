# Hardware Overview — MainServer (Intel N100)

This file documents the physical hardware setup and configuration for the MainServer machine.

## System

- **Model:** Topton M4 Mini PC
- **CPU:** Intel N100 (Alder Lake-N, 3.40 GHz, 6 MB cache, 4 cores, 4 threads, 6 W TDP)
- **GPU**: Intel UHD Graphics (integrated)
- **Memory:** Crucial - DDR4 - 32 GB - SO DIMM 260-PIN - 3200 MHz / PC4-25600 - CL22 - 1.2 V - unbuffered - non-ECC (CT32G4SFD832A)
- **Motherboard:** Custom Topton board with Realtek NICs
- **Firmware:** UEFI (Secure Boot disabled)

## Storage

| Device    | Type                      | Capacity | Role                             |
| --------- | ------------------------- | -------- | -------------------------------- |
| NVMe SSD  | M.2 2280 (FIKWOT FN960)   | 2 TB     | ZFS root, swap, cachepool        |
| mSATA SSD | Kingchuxing 2TB (V0919A0) | 2 TB     | SnapRAID data (`/mnt/data1`)     |
| SATA SSD  | INTENSO SSD (W0413A0)     | 2 TB     | SnapRAID parity (`/mnt/parity1`) |

## Networking

- 2x Realtek RTL8111/8168/8411 Gigabit Ethernet (RJ45)

## Power & Cooling

- 12V DC input, passively cooled: LEICKE 72W Power supply unit 12V 6A with additional 5 mm DC extension cable
- Consumes ~6–10W idle

## Additional Notes

- Boot via NVMe (UEFI)
- No ECC RAM support
- Serial ports unused
- Dual HDMI + DisplayPort output (not used)
