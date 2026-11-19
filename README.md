# kali-wsl-lab

A beginner-friendly, step-by-step guide to running **Kali Linux on WSL2 (Windows 11)**: install it, move it to another drive, get a desktop GUI, tune performance, and fix the errors you are most likely to hit. Every step explains *why* it works, not just what to type.

> Built from a real setup session, including the mistakes and their fixes (see [Troubleshooting](#troubleshooting)).

---

## Table of contents

1. [What you will learn](#what-you-will-learn)
2. [Prerequisites](#prerequisites)
3. [Quick start](#quick-start)
4. [Move Kali to another drive](#move-kali-to-another-drive)
5. [Set the default user](#set-the-default-user)
6. [Get a desktop GUI](#get-a-desktop-gui)
7. [Install Kali tools](#install-kali-tools)
8. [Performance tuning](#performance-tuning)
9. [USB devices in WSL](#usb-devices-in-wsl)
10. [How it works (concepts)](#how-it-works-concepts)
11. [Troubleshooting](#troubleshooting)
12. [Responsible use](#responsible-use)
13. [Roadmap](#roadmap)
14. [Contributing](#contributing)
15. [License](#license)

---

## What you will learn

- What WSL2 is and how it differs from a normal virtual machine
- Which Windows optional features are needed (and which are not)
- How to install Kali and relocate its virtual disk to `D:`
- How to fix the default-user and `wsl.conf` problems
- How to run a full Kali desktop (Win-KeX or xrdp)
- How to limit WSL's memory and CPU use
- How USB devices can be shared with WSL, and the limits of that

## Prerequisites

| Requirement | Notes |
|---|---|
| Windows 11 | Windows 10 22H2 also works for most steps |
| Virtualization enabled in BIOS/UEFI | Task Manager → Performance → CPU → "Virtualization: Enabled" |
| 8 GB RAM minimum (16 GB recommended) | A full desktop plus tools is memory hungry |
| 20+ GB free disk | The `ext4.vhdx` grows as you install tools |

## Quick start

Open **PowerShell** and run:

```powershell
wsl --update
wsl --set-default-version 2
wsl --install -d kali-linux
```

The Windows features it relies on are **Windows Subsystem for Linux** and **Virtual Machine Platform** (`optionalfeatures` → tick both → restart). `wsl --install` enables them for you. Full Hyper-V is **not** required.

On first launch, Kali asks you to create a username and password. There is **no default password** in WSL; the one you choose is the one `sudo` asks for. Nothing appears on screen while you type it, which is normal.

Then update everything:

```bash
sudo apt update && sudo apt full-upgrade -y
```

## Move Kali to another drive

By default the distro's disk lives on `C:`. The WSL feature itself stays on `C:`, but the large `ext4.vhdx` can live anywhere.

First check the exact distro name (you may have named it `kali`, not `kali-linux`):

```powershell
wsl --list --verbose
```

Then move it (needs a recent WSL; run `wsl --update` first):

```powershell
wsl --shutdown
mkdir D:\WSL\kali
wsl --manage kali --move D:\WSL\kali
```

Verify: `D:\WSL\kali` should now contain `ext4.vhdx`. Start it with `wsl -d kali`.

**Older WSL without `--manage`?** Use export/import:

```powershell
wsl --shutdown
wsl --export kali D:\WSL\backup\kali.tar
wsl --unregister kali          # deletes the C: copy; confirm the .tar exists first
wsl --import kali D:\WSL\kali D:\WSL\backup\kali.tar --version 2
```

After an import you log in as `root` until you set the default user (next section).

## Set the default user

Edit `/etc/wsl.conf` inside Kali. Replace `YOURUSER` with the name shown by `ls /home`:

```ini
[boot]
systemd=true

[user]
default=YOURUSER
```

Then restart WSL from PowerShell:

```powershell
wsl --shutdown
wsl -d kali
```

> **Pitfall:** do not append a `default=` line with `echo >>` if one already exists. A duplicate key triggers `Duplicated config key 'user.default'` and WSL falls back to root. Rewrite the whole file instead.

## Get a desktop GUI

**Windows 11 already runs individual Linux GUI apps** through WSLg. For a full desktop pick one of:

**Option A: Win-KeX (easiest)**

```bash
sudo apt install -y kali-win-kex
kex --win -s      # windowed desktop with sound
kex --esm -s      # enhanced session mode (Windows RDP client, smoother)
kex stop          # end the session
```

**Option B: xrdp + Windows Remote Desktop**

```bash
sudo apt install -y kali-desktop-xfce xrdp
sudo sed -i 's/port=3389/port=3390/g' /etc/xrdp/xrdp.ini
echo xfce4-session > ~/.xsession
sudo systemctl enable --now xrdp
```

Then run `mstsc` and connect to `localhost:3390`. This needs `systemd=true` (set above). Port 3390 avoids clashing with Windows' own RDP port.

## Install Kali tools

The WSL image is minimal. Install what you need:

```bash
sudo apt install -y kali-linux-headless   # core tools, no GUI
# or
sudo apt install -y kali-linux-default    # larger default toolset
```

Installing individual tools (`sudo apt install nmap`) saves disk space.

## Performance tuning

Optional features do not make a laptop faster; the real gains are elsewhere.

Create `C:\Users\<you>\.wslconfig`:

```ini
[wsl2]
memory=4GB
processors=4
```

Adjust to your hardware, then run `wsl --shutdown`. Other tips:

- Keep project files in the Linux filesystem (`~/projects`), **not** under `/mnt/c/`. Cross-filesystem access is much slower.
- Reclaim disk space after deleting files: `wsl --shutdown`, then `wsl --manage kali --set-sparse true`.
- Trim Windows startup apps in Task Manager → Startup apps.

## USB devices in WSL

WSL2 has no built-in USB support. [usbipd-win](https://github.com/dorssel/usbipd-win) shares a USB device from Windows into WSL over a virtual network (USB/IP).

In an **Administrator** PowerShell:

```powershell
winget install usbipd
usbipd list                          # find the BUSID
usbipd bind --busid <BUSID>
usbipd attach --wsl --busid <BUSID>
```

In Kali: `sudo apt install usbutils` then `lsusb`.

**Important limit:** sharing the device only makes it *visible*. WSL's stock kernel ships a limited set of drivers, so many devices (including most Wi-Fi adapters) will not work without a custom kernel. For hardware-heavy work, a full VM (VirtualBox/VMware) or a live USB is usually the practical choice.

## How it works (concepts)

- **WSL2** runs a real Linux kernel inside a lightweight Hyper-V VM. All installed distros share that one kernel.
- **Kernel vs userland:** the kernel (hardware access, drivers) is provided by Microsoft. Kali only supplies the userland (tools, libraries, package manager).
- **Why `/mnt/c` opens by default:** WSL starts in the Windows folder you launched it from, mapped under `/mnt/c`. Your Linux home is `~`. Use `wsl ~ -d kali` to start there.
- **Why the disk grows but does not shrink:** `ext4.vhdx` is a virtual disk file; it expands on demand. Use sparse mode to reclaim space.
- **Networking:** WSL2 gets a virtual network adapter. Linux does not see Windows' physical Wi-Fi card; that is why hardware-level wireless work does not carry over directly.

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `Invalid command line argument: --help` on `wsl --manage` | `--manage` does not take `--help` | Use `wsl --help` to list options |
| `Duplicated config key 'user.default'` | Two `default=` lines in `/etc/wsl.conf` | Rewrite the file cleanly (see above) |
| `getpwnam(...) failed` | `default=` names a user that does not exist | Check `ls /home` and fix the name |
| Logged in as root after import | Default user not set | Set `[user] default=` in `/etc/wsl.conf` |
| Shell starts in `/mnt/c/Users/...` | WSL inherits the launch folder | `wsl ~ -d kali` or add `cd ~` to `~/.zshrc` |
| Forgot password | n/a | `wsl -d kali -u root`, then `passwd <user>` |
| xrdp black screen / instant disconnect | Duplicate session or service not running | Close other sessions, `sudo systemctl restart xrdp` |
| Virtualization error on install | Disabled in BIOS | Enable Intel VT-x / AMD SVM |

## Responsible use

Kali ships security tools. Use them **only on systems and networks you own or have explicit written permission to test**. This repository documents environment setup and administration, not attacks on third parties.

## Roadmap

- [ ] Scripted, repeatable setup (PowerShell + bash)
- [ ] Windows Terminal profile and dotfiles
- [ ] Backup and restore workflow for the distro
- [ ] Comparison: WSL2 vs VirtualBox vs live USB vs dual boot
- [ ] Defensive lab exercises (hardening a home router, auditing your own services)

## Contributing

Issues and pull requests are welcome. Please:

1. State your Windows build (`winver`) and WSL version (`wsl --version`).
2. Include the exact command and full error text.
3. Keep explanations beginner-friendly.

## License

MIT. Add a `LICENSE` file before publishing.