# Troubleshooting

Start by gathering facts:

```powershell
wsl --version
usbipd --version
usbipd list
```

```bash
uname -r
./scripts/usb-check.sh
```

## Windows side (PowerShell)

| Symptom | Cause | Fix |
|---|---|---|
| `usbipd : The term 'usbipd' is not recognized` | PATH not refreshed or not installed | Reopen PowerShell; or reinstall: `winget install --interactive --exact dorssel.usbipd-win` |
| `usbipd: error: Access denied` on `bind` | Not Administrator | Open PowerShell as Administrator for `bind` |
| `bind` fails because another program uses the device | A filter driver or virtualization tool holds it | `usbipd bind --busid <ID> --force` (Administrator) |
| `attach` fails: no WSL distro running / VM not running | WSL is stopped | Open a Linux terminal first, or run `wsl --exec true` |
| `attach` complains about version | Old WSL or usbipd | `wsl --update` and update usbipd-win with `winget upgrade dorssel.usbipd-win` |
| Device not listed in `usbipd list` | Not recognised by Windows | Try another port or cable; check Device Manager |
| BUSID changed | Device plugged into a different port | Run `usbipd list` again, or use the script's `-HardwareId` |
| Script is blocked | PowerShell execution policy | `powershell -ExecutionPolicy Bypass -File .\scripts\usb-attach.ps1 -List` |
| Windows lost the device | Expected: WSL owns it while attached | `usbipd detach --busid <ID>` |

## Linux side (WSL)

| Symptom | Cause | Fix |
|---|---|---|
| Not in `lsusb` after attach | Attach failed, or WSL restarted | Re-run `usbipd attach`; check for errors on the Windows side |
| In `lsusb` but no `/dev/ttyUSB0`, `/dev/sdb`, `/dev/video0` | No kernel driver claimed it | `dmesg | tail`; try `sudo modprobe cp210x` (or the right driver); otherwise see [custom-kernel.md](custom-kernel.md) |
| `modprobe: FATAL: Module ... not found` | Driver not in your kernel | Update WSL (`wsl --update`) or build a custom kernel |
| `Permission denied` on `/dev/ttyUSB0` | You are not in `dialout` | `sudo usermod -aG dialout $USER`, then `wsl --shutdown` and reopen |
| Disk shows as `/dev/sdb` but will not mount | Unsupported filesystem (exFAT/NTFS) | `sudo apt install exfat-fuse ntfs-3g`, or use `wsl --mount` instead |
| Device vanished after reboot or `wsl --shutdown` | Attachments are not persistent | Re-attach, or use `--auto-attach` |
| Data missing after unplugging a drive | Not unmounted | Always `sudo umount` first |
| Serial output garbled | Wrong baud rate | Match the device (`screen /dev/ttyUSB0 115200`) |

## Still stuck?

Open an issue with:

1. The output of the commands at the top of this page
2. The device's `VID:PID`
3. The exact command you ran and its full error text
