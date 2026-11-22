#!/usr/bin/env bash
# usb-check.sh - quick diagnostics for USB devices inside WSL2.
# Usage: ./usb-check.sh
# Prints what Linux can see after you attach a device with usbipd.

section() { printf '\n=== %s ===\n' "$1"; }

section "Kernel"
uname -r

section "USB devices (lsusb)"
if command -v lsusb >/dev/null 2>&1; then
    lsusb
else
    echo "lsusb not found. Install it: sudo apt install usbutils"
fi

section "Device nodes"
ls -l /dev/ttyUSB* /dev/ttyACM* /dev/sd? /dev/sd?? /dev/video* 2>/dev/null \
    || echo "No serial, disk or video nodes found."

section "USB-related kernel modules loaded"
lsmod 2>/dev/null | grep -Ei 'usb|vhci|cp210x|ch341|ftdi|pl2303|cdc|uvc|uas|hid' \
    || echo "None listed (a driver may be built into the kernel, or missing)."

section "Recent kernel messages about USB"
dmesg 2>/dev/null | grep -i usb | tail -n 20 \
    || echo "dmesg not readable. Try: sudo dmesg | grep -i usb | tail"

section "Your groups (serial devices need 'dialout')"
id -nG

cat <<'EOF'

How to read this:
  - Device in lsusb AND a /dev node  -> working.
  - Device in lsusb but no /dev node -> no driver claimed it (check dmesg; try
                                         `sudo modprobe <driver>`; see docs/custom-kernel.md).
  - Device not in lsusb              -> attach did not succeed; check usbipd on Windows.
EOF
