# MINIX Z100-0dB - AC Power Recovery Configuration Guide

**Asset Tag:** ASSET-0039
**Hostname:** homeseer
**Location:** Server Closet
**Purpose:** Home Automation Server (Blue Iris, HomeSeer HS4)

---

## Device Specifications

| Specification | Value |
|---------------|-------|
| Manufacturer | MINIX |
| Model | NEO Z100-0dB |
| Processor | Intel Alder Lake-N Quad-Core N100 (up to 3.40GHz) |
| RAM | 16GB DDR4 3200MHz |
| Storage | 512GB M.2 PCIe NVMe SSD |
| Operating System | Windows 11 Pro |
| Network | IP: 192.168.68.56 (DHCP Reserved) |
| MAC Address | a0:1e:0b:15:75:b7 |

---

## Problem Statement

After a power outage, this mini PC remains OFF and requires manual pressing of the power button to turn on. This can be changed via a BIOS setting so the PC automatically powers on when electricity is restored.

---

## How to Access BIOS

1. Connect a USB keyboard to the mini PC
2. Power on or restart the device
3. Immediately and repeatedly press the **Del** key (or try **F2** as alternative)
4. The AMI BIOS setup utility will appear

**Note:** You must press the key before the Windows logo appears. If you miss it, restart and try again.

---

## Configuring AC Power Recovery

### To Enable Auto Power-On (Recommended for Servers)

1. Enter BIOS (see above)
2. Navigate to: **Chipset** → **PCH-IO Configuration**
3. Find the setting: **State After G3**
4. Change the value to: **S0 State**
5. Press **F4** to save and exit
6. Confirm save when prompted

| Setting Value | Behavior |
|---------------|----------|
| **S0 State** | PC turns ON automatically when power is restored |
| **S5 State** | PC stays OFF until power button is pressed (default) |
| **Last State** | PC returns to whatever state it was in before power loss |

### Alternative Menu Paths

If the above path doesn't exist, look for one of these:
- **Advanced** → **Power Management** → **Restore AC Power Loss**
- **Advanced** → **APM Configuration** → **Restore on AC Power Loss**
- **Boot** → **Power On After Power Failure**

---

## Verifying the Setting Works

1. After saving the BIOS setting, boot into Windows
2. Shut down the PC normally
3. Unplug the power cord from the wall outlet
4. Wait 30 seconds
5. Plug the power cord back in
6. The PC should automatically power on without pressing the power button

**Important:** The AC Power Recovery function requires the system to be in a true power-off state (G3). Wait at least 30 seconds with power disconnected before testing.

---

## To Disable Auto Power-On

Follow the same steps above, but set **State After G3** to **S5 State** (or "Power Off" / "Stay Off" depending on BIOS version).

---

## Official Manufacturer Resources

| Resource | URL |
|----------|-----|
| MINIX Official Website | https://www.minix.com.hk |
| Product Page | https://www.minix.com.hk/products/z100-0db-fanless-n100-mini-pc |
| Download Center | https://www.minix.com.hk/pages/download-center |
| Contact Support | https://www.minix.com.hk/pages/contact |
| Warranty & After-Sales | https://www.minix.com.hk/pages/after-sales-service |
| User Manual (PDF) | https://www.manualslib.com/download/3444498/Minix-Neo-Z100-0db.html |

---

## Quick Reference Card

```
+----------------------------------------------------------+
|  MINIX Z100-0dB - AUTO POWER ON QUICK REFERENCE          |
+----------------------------------------------------------+
|  1. Press DEL key repeatedly during boot to enter BIOS   |
|  2. Go to: Chipset → PCH-IO Configuration                |
|  3. Set "State After G3" to "S0 State"                   |
|  4. Press F4 to save and exit                            |
+----------------------------------------------------------+
|  S0 State = Auto Power ON                                |
|  S5 State = Stay OFF (default)                           |
|  Last State = Return to previous state                   |
+----------------------------------------------------------+
```

---

*Document Created: December 19, 2025*
*Asset Management System: Snipe-IT (http://192.168.68.56:8082)*
