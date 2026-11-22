<#
.SYNOPSIS
  Helper for sharing USB devices with WSL2 through usbipd-win.

.DESCRIPTION
  Finds a device by BUSID or VID:PID, binds it if needed (needs an elevated
  PowerShell for that step only), and attaches it to WSL. Can also detach.

.EXAMPLE
  .\usb-attach.ps1 -List

.EXAMPLE
  .\usb-attach.ps1 -HardwareId 1a86:7523

.EXAMPLE
  .\usb-attach.ps1 -BusId 2-1 -AutoAttach

.EXAMPLE
  .\usb-attach.ps1 -BusId 2-1 -Detach
#>
[CmdletBinding()]
param(
    [string]$BusId,
    [string]$HardwareId,     # VID:PID such as 1a86:7523
    [switch]$AutoAttach,     # keep re-attaching (usbipd-win 4.0 or later)
    [switch]$Detach,
    [switch]$List
)

$ErrorActionPreference = "Stop"

if (-not (Get-Command usbipd -ErrorAction SilentlyContinue)) {
    throw "usbipd not found. Install it with: winget install --interactive --exact dorssel.usbipd-win (then reopen PowerShell)."
}

function Test-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    return ([Security.Principal.WindowsPrincipal]$id).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Parse `usbipd list` into objects (BusId, HardwareId, Text)
function Get-UsbDevices {
    $rows = @()
    foreach ($line in (usbipd list)) {
        if ($line -match '^\s*(\d+-[\d.]+)\s+([0-9a-fA-F]{4}:[0-9a-fA-F]{4})\s+(.*)$') {
            $rows += [pscustomobject]@{
                BusId      = $Matches[1]
                HardwareId = $Matches[2].ToLower()
                Text       = $Matches[3].Trim()
            }
        }
    }
    return $rows
}

if ($List) {
    usbipd list
    return
}

if (-not $BusId -and -not $HardwareId) {
    throw "Give -BusId or -HardwareId (or use -List to see devices)."
}

$devices = Get-UsbDevices

if (-not $BusId) {
    $found = @($devices | Where-Object { $_.HardwareId -eq $HardwareId.ToLower() })
    if ($found.Count -eq 0) { throw "No device with VID:PID $HardwareId found. Is it plugged in? Run with -List." }
    if ($found.Count -gt 1) {
        $found | Format-Table BusId, HardwareId, Text | Out-String | Write-Host
        throw "More than one device matches. Re-run with -BusId."
    }
    $BusId = $found[0].BusId
}

$device = $devices | Where-Object { $_.BusId -eq $BusId }
if (-not $device) { throw "BUSID $BusId not found. Run with -List." }
Write-Host "Device: $($device.BusId)  $($device.HardwareId)  $($device.Text)"

if ($Detach) {
    usbipd detach --busid $BusId
    if ($LASTEXITCODE -ne 0) { throw "detach failed." }
    Write-Host "Detached. The device is back with Windows."
    return
}

# Bind only if the device is not shared yet (this step needs Administrator)
if ($device.Text -match 'Not shared') {
    if (-not (Test-Admin)) {
        throw "Device is not shared yet. Run this once in an Administrator PowerShell to bind it (or run: usbipd bind --busid $BusId)."
    }
    usbipd bind --busid $BusId
    if ($LASTEXITCODE -ne 0) { throw "bind failed. If another tool holds the device, try: usbipd bind --busid $BusId --force" }
}

# Make sure WSL is running, because attach needs a running VM
wsl.exe --exec true | Out-Null

$attachArgs = @("attach", "--wsl", "--busid", $BusId)
if ($AutoAttach) { $attachArgs += "--auto-attach" }

usbipd @attachArgs
if ($LASTEXITCODE -ne 0) { throw "attach failed. See docs/troubleshooting.md." }

if (-not $AutoAttach) {
    Write-Host "Attached. In Linux, run: lsusb"
}
