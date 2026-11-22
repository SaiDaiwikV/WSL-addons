# Custom WSL2 kernel (when a USB driver is missing)

Use this only if your device appears in `lsusb` but no driver claims it, and `modprobe` says the module does not exist.

> **Try first:** run `wsl --update`. A newer stock kernel may already include the driver.

## How it works

WSL2 runs Microsoft's Linux kernel. Drivers are either **built in** (`=y`), shipped as **modules** (`=m`), or **absent**. If yours is absent, you build a kernel with it enabled and tell WSL to boot that kernel with `.wslconfig`. A custom kernel replaces the stock one, so it does not receive kernel updates from `wsl --update` until you remove the setting.

These steps follow Microsoft's published kernel repository; adapt the driver list to your device.

## 1. Pick the branch that matches your kernel

```bash
uname -r        # e.g. 6.6.87.2-microsoft-standard-WSL2  → branch linux-msft-wsl-6.6.y
```

Available branches include `linux-msft-wsl-5.15.y`, `linux-msft-wsl-6.1.y` and `linux-msft-wsl-6.6.y`. Check the [repository](https://github.com/microsoft/WSL2-Linux-Kernel) for newer ones.

## 2. Install build tools and get the source

```bash
sudo apt update
sudo apt install -y build-essential flex bison libssl-dev libelf-dev bc dwarves python3 cpio git
git clone --depth 1 -b linux-msft-wsl-6.6.y https://github.com/microsoft/WSL2-Linux-Kernel.git
cd WSL2-Linux-Kernel
```

## 3. Start from Microsoft's config and enable your driver

```bash
cp Microsoft/config-wsl .config
```

Enable only what you need. `--enable` sets the option to built-in (`=y`), which avoids needing to install modules:

| Device chip | Option(s) |
|---|---|
| Silicon Labs CP210x | `USB_SERIAL_CP210X` |
| WCH CH340/CH341 | `USB_SERIAL_CH341` |
| FTDI | `USB_SERIAL_FTDI_SIO` |
| Prolific PL2303 | `USB_SERIAL_PL2303` |
| Arduino / CDC-ACM | `USB_ACM` |
| USB mass storage | `USB_STORAGE` |
| UVC webcams | `USB_VIDEO_CLASS` |
| exFAT filesystem | `EXFAT_FS` |

Example:

```bash
scripts/config --enable USB_SERIAL --enable USB_SERIAL_CP210X --enable EXFAT_FS
make olddefconfig
```

To find the option for another device, search the kernel's `Kconfig` files for its name or chip.

## 4. Build

```bash
make -j"$(nproc)"
sudo make modules_install     # keeps the options Microsoft ships as modules (=m) working
```

This takes a while and a few GB of disk. The result is `arch/x86/boot/bzImage`.

## 5. Tell WSL to use it

Copy the image somewhere on Windows, for example `D:\WSL\kernel\`:

```bash
mkdir -p /mnt/d/WSL/kernel
cp arch/x86/boot/bzImage /mnt/d/WSL/kernel/bzImage
```

Edit `C:\Users\<you>\.wslconfig` (create it if missing). Use double backslashes:

```ini
[wsl2]
kernel=D:\\WSL\\kernel\\bzImage
```

Then in PowerShell:

```powershell
wsl --shutdown
wsl
```

Inside Linux, `uname -r` should show your build.

## Roll back

Delete the `kernel=` line from `.wslconfig` and run `wsl --shutdown`. WSL returns to the stock kernel.

## Notes

- Keep your kernel branch close to your stock version so userland tools stay compatible.
- Commit your final `.config` to your own repo if you want the build to be reproducible.
- If the build fails for lack of space or memory, raise WSL's limits in `.wslconfig` (`memory=`) and clean with `make clean`.
