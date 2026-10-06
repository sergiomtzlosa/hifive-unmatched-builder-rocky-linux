# HiFive Unmatched Hardware Setup Guide

## Board Overview

The **SiFive HiFive Unmatched Rev B** is a RISC-V development board featuring:
- **CPU:** SiFive FU740 (4x U74 64-bit cores @ up to 1.5GHz + 1x S7 monitor core)
- **RAM:** 16GB DDR4
- **Storage:** MicroSD card slot, M.2 NVMe slot (PCIe 3.0 x4)
- **Networking:** Gigabit Ethernet
- **USB:** 4x USB 3.2 Gen 1 ports
- **PCIe:** x16 slot (x8 electrical)
- **Form Factor:** Mini-ITX

## MSEL Switch Configuration

The MSEL (Mode Select) DIP switches determine the boot source. They are located next to the RTC battery and assembly number on the board.

### For SD Card Boot (Default)

Set MSEL[3:0] = `1011`:

```
   MSEL Switch Block
   +-------------+
   | 0 1 2 3 C   |  <- Switch labels
   +-+-+-+-+-----+
   |*|*| |*|     |  <- ON position (toward center)
   | | |*| |*    |  <- OFF position (toward edge)
   +-+-+-+-+-----+
     1 1 0 1

   Position: ON  ON  OFF ON  (OFF)
   Binary:   1   1   0   1
   Hex:      0xB (MSEL[3:0])
```

**Switch Settings:**
- MSEL0: ON  (1)
- MSEL1: ON  (1)
- MSEL2: OFF (0)
- MSEL3: ON  (1)
- CHIPIDSEL: OFF (default)

### Other Boot Modes

- **QSPI Flash:** `0110` (Not used in this guide)
- **JTAG:** `1111` (For debugging)

**Important:** Always power off the board before changing MSEL switches!

## Serial Console Connection

### Hardware Connection

1. **Locate the micro-USB port** on the HiFive Unmatched (near the Ethernet port)
2. **Connect a micro-USB cable** from your PC to the board
3. **Install drivers** (usually automatic on Windows 10/11)
4. **Find the COM port:**
   - Open Device Manager (Win + X -> Device Manager)
   - Expand "Ports (COM & LPT)"
   - Look for "USB Serial Port (COMx)" or "Silicon Labs CP210x"
   - Note the COM port number (e.g., COM3)

### Terminal Settings

Configure your terminal software with these settings:

| Parameter      | Value     |
|----------------|-----------|
| Baud rate      | 115200    |
| Data bits      | 8         |
| Stop bits      | 1         |
| Parity         | None      |
| Flow control   | None      |
| Local echo     | Off       |

### Terminal Software Options

**Windows:**
- **PuTTY** (Recommended)
  - Download: https://www.putty.org/
  - Connection type: Serial
  - Serial line: COM3 (or your COM port)
  - Speed: 115200
  
- **TeraTerm**
  - Download: https://ttssh2.osdn.jp/
  - Setup -> Serial port -> Select COM port
  - Setup -> Serial port -> Speed: 115200

- **Windows Terminal** (with WSL)
  ```bash
  screen /dev/ttyS3 115200  # Adjust COM port number
  ```

**Linux:**
```bash
screen /dev/ttyUSB0 115200
# or
minicom -D /dev/ttyUSB0 -b 115200
# or
picocom -b 115200 /dev/ttyUSB0
```

## SD Card Preparation

### Recommended SD Cards

- **Capacity:** Minimum 4GB, recommended 8GB or larger
- **Speed:** Class 10 or better, UHS-I recommended
- **Brands:** SanDisk, Samsung, or other reputable brands
- **Format:** Will be overwritten (current format doesn't matter)

### Known Compatible Cards

[OK] **Tested and Working:**
- SanDisk Ultra 16GB Class 10
- Samsung EVO Plus 32GB UHS-I
- Kingston Canvas Select Plus 16GB Class 10

**Problematic Cards:**
- Some generic/no-name cards may not work reliably
- Very old cards (< Class 4) are too slow

## Power Supply

### Requirements

- **Voltage:** 12V DC
- **Current:** Minimum 3A, recommended 5A
- **Connector:** ATX 24-pin (standard PC motherboard connector)

### Using ATX Power Supply

The HiFive Unmatched uses a standard ATX 24-pin connector and can be powered by:

1. **Full ATX Power Supply**
   - Connect 24-pin ATX connector
   - Ensure PSU is plugged in and switched on
   - Use the onboard power button or short the power pins

2. **ATX Breakout Board** (Recommended for development)
   - Allows using ATX PSU without full PC case
   - Provides easy on/off switch
   - Example: DROK ATX Breakout Board

3. **Standalone 12V Power Adapter**
   - Not officially supported but some use picoPSU
   - Requires proper ATX pin configuration

### Power Button

- Located on the board near the ATX connector
- Short press: Power on
- Long press (4s): Force power off

## Network Setup

### Ethernet Connection

1. Connect Ethernet cable to RJ45 port
2. Board should obtain IP via DHCP by default
3. Check IP address after boot:
   ```bash
   ip addr show
   ```

### Network LEDs

- **Green LED:** Link status (on when connected)
- **Orange LED:** Activity (blinks during traffic)

## Storage Options

### SD Card (Primary Boot)

- Used for bootloader (U-Boot SPL + U-Boot)
- Can also host root filesystem
- Must remain inserted for boot

### NVMe SSD (Optional)

- **Slot:** M.2 2280 (PCIe 3.0 x4)
- **Supported:** Most standard NVMe SSDs
- **Use case:** Fast root filesystem (recommended)
- **Setup:** See NVMe Boot Guide

### PCIe Devices

- x16 slot (x8 electrical)
- Compatible with standard PCIe cards
- GPU support depends on Linux drivers

## LED Indicators

### Power LED (D18)
- **Off:** No power
- **On:** Power good

### D12 LED
- **Heartbeat:** Configured by default (in setup scripts)
- Blinks to show system is alive

### D2 RGB LED
- **Yellow:** During boot (U-Boot/kernel loading)
- **Green:** System booted successfully
- **Red:** Error condition

## First Boot Checklist

Before powering on:

- [ ] MSEL switches set to `1011`
- [ ] SD card inserted with flashed image
- [ ] Serial console connected and terminal open
- [ ] Ethernet cable connected (optional but recommended)
- [ ] ATX power connected
- [ ] No PCIe cards installed (for first boot, add later)

Power on sequence:

1. **Apply power** (ATX PSU on, plug in)
2. **Press power button** on board
3. **Watch serial console** for boot messages
4. **Wait for login prompt** (may take 30-60 seconds)

## Expected Boot Sequence

```
1. ROM ZSBL runs (no output)
2. U-Boot SPL loads (brief messages)
3. OpenSBI loads (version banner)
4. U-Boot starts (banner and version)
5. Extlinux menu appears (press key to interrupt, or auto-boot)
6. Kernel loading messages
7. Systemd initialization
8. Login prompt appears
```

## Troubleshooting Boot Issues

### No Serial Output

- Check USB cable connection
- Verify COM port in Device Manager
- Try different USB port
- Check terminal settings (115200 baud)
- Try different terminal software

### Board Won't Power On

- Check ATX power supply is on
- Verify 24-pin connector seated properly
- Check MSEL switches are correct
- Try holding power button longer (3-5 seconds)
- Check for power LED illumination

### Boots to U-Boot but Stops

- Check SD card is properly seated
- Verify image was written correctly
- Check extlinux.conf syntax
- Try reflashing the SD card

### Kernel Panic or Boot Failure

- Verify kernel and DTB exist in /boot
- Check root device path in extlinux.conf
- Verify filesystem on partition 3 is not corrupt
- Check for any visible errors in boot messages

## Safety Precautions

**Important Safety Notes:**

- Always power off before connecting/disconnecting components
- Never change MSEL switches while powered on
- Handle board by edges, avoid touching components
- Use ESD protection when handling
- Ensure adequate ventilation (board can get warm)
- Don't short circuit power pins
- Keep liquids away from the board

## Additional Resources

- [SiFive HiFive Unmatched Product Page](https://www.sifive.com/boards/hifive-unmatched)
- [SiFive HiFive Unmatched Getting Started Guide](https://sifive.cdn.prismic.io/sifive/1a82e600-1f93-4f41-b2d8-86ed8b16acf7_hifive-unmatched-getting-started-guide-v1p0.pdf)
- [SiFive Forums](https://forums.sifive.com/)

## Next Steps

Once hardware is set up:
1. Flash your built image to SD card (see README.md)
2. Insert SD card and boot
3. Access via serial console
4. Login and start using your Rocky Linux system!
