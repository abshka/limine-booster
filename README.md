# Limine Booster

A zero-configuration, automated tool to manage Limine bootloader entries for Arch Linux kernels with Booster initramfs.

This tool provides a pacman hook that automatically creates and updates Limine entries for all installed kernels, using the command line from your currently running system. No manual configuration is required.

The generated entries are fully compatible with `limine-snapper-sync` for BTRFS snapshot management. When kernels are removed, the tool automatically calls `limine-snapper-sync` to update snapshot entries, ensuring complete integration.

## Features

- **Zero-Configuration:** Works out of the box. No need to edit config files after installation.
- **Fully Automated:** A pacman hook handles everything automatically when you install, upgrade, or remove any kernel.
- **Multi-Kernel Support:** Automatically creates and manages separate entries for all installed kernels (e.g., `linux`, `linux-lts`, `linux-zen`).
- **Smart Hook Logic:** Intelligently processes only changed kernels or all kernels based on the type of update.
- **Automatic Cleanup:** Removes entries when kernel packages are uninstalled and automatically calls `limine-snapper-sync` to update snapshots.
- **Smart Cmdline Detection:** Uses the command line from your running system (`/proc/cmdline`) for new entries.
- **Automatic Microcode Detection:** Includes Intel/AMD microcode if available.
- **Enhanced AUR Support:** Robust detection and handling of AUR kernels with advanced pattern matching.

## Installation

Install the package from the Arch User Repository (AUR). For example, using `yay`:

```bash
yay -S limine-booster
```

## Usage

**1. Install the package.**

**2. Install or update any kernel.**

That's it. The tool will automatically create entries in your `/boot/limine.conf` for the kernel you just installed.

## Entry Format

The tool creates entries compatible with `limine-snapper-sync`:

- A main entry: `/+Arch Linux` with machine-id comment for automatic OS detection
- Sub-entries for each kernel: `//kernel-name kernel-version`

For example, after installing the `linux-lts` package, you'll see:

```
/+Arch Linux
    comment: machine-id=your-machine-id

//linux-lts 6.6.52-1-lts
    protocol: linux
    comment: Auto-generated for linux-lts 6.6.52-1-lts (Booster)
    kernel_path: boot():/machine-id/linux-lts/vmlinuz-linux-lts
    module_path: boot():/intel-ucode.img
    module_path: boot():/machine-id/linux-lts/booster-linux-lts.img
    kernel_cmdline: your-kernel-parameters
```

## Included Commands

**limine-booster** includes its own implementation of essential Limine commands:

- **limine-enroll-config**: Enroll Limine configuration into UEFI binary
- **limine-reset-enroll**: Reset enrolled configuration from UEFI binary

These commands are compatible with `limine-snapper-sync` and provide full independence from other packages.

### Configuration Enrollment

Configuration enrollment allows embedding the Limine config directly into the EFI binary for enhanced security:

```bash
# Enable enrollment (disabled by default for safety)
export ENABLE_ENROLL_LIMINE_CONFIG=yes

# Enroll current config into Limine binary
sudo limine-enroll-config

# Reset enrolled config (remove embedded config)
sudo limine-reset-enroll
```

**Path Detection**: The commands automatically detect Limine binary location:

1. `/boot/EFI/Limine/limine_x64.efi` (preferred)
2. `/boot/EFI/BOOT/BOOTX64.EFI` (fallback)
3. `/boot/BOOTX64.EFI` (legacy)

You can override with: `LIMINE_BINARY_PATH=/custom/path limine-enroll-config`

### limine-snapper-sync Integration

The tool is fully integrated with `limine-snapper-sync`:

- **Machine-ID Detection**: The main entry includes `comment: machine-id=<machine-id>` which allows `limine-snapper-sync` to automatically target the correct OS entry regardless of the OS name configuration.
- **Proper Module Order**: Microcode is placed after the kernel and before the initramfs for optimal boot performance.
- **Snapshot Integration**: The `/+` prefix enables automatic BTRFS snapshot functionality.
- **Automatic Synchronization**: When kernels are removed, `limine-booster` automatically calls `limine-snapper-sync` to update snapshot entries, ensuring consistency between main entries and snapshots.
- **Separation of Concerns**: `limine-booster` manages only the main `/+Arch Linux` section, while `limine-snapper-sync` handles all `//Snapshots` entries.

### Advanced Configuration (Optional)

For most users, no configuration is needed. However, if you need to override the default behavior, you can edit `/etc/default/limine-booster.conf`.

**Override Kernel Command Line:**

By default, the script uses the command line from `/proc/cmdline`. You can specify a custom one:

```ini
# /etc/default/limine-booster.conf
CMDLINE_OVERRIDE="root=UUID=... rw quiet"
```

## Troubleshooting

### limine-snapper-sync Integration

This tool is fully compatible with `limine-snapper-sync` for BTRFS snapshot integration. The included `limine-enroll-config` and `limine-reset-enroll` commands provide full support for snapshot functionality without requiring additional packages.

### AUR Kernel Support

This tool provides robust support for AUR and custom kernels:

- **Dual Detection Method**: Searches both `/usr/lib/modules/*/vmlinuz` (standard) and `/boot/vmlinuz-*` (AUR/custom) locations
- **Smart Package Detection**: Uses advanced pattern matching to correctly identify AUR kernel packages during removal
- **Enhanced Fallback Logic**: When package information is unavailable, uses intelligent pattern matching based on kernel version strings
- **Automatic Cleanup**: Properly removes entries for AUR kernels using the same automated `limine-snapper-sync` integration

### Entry Structure Issues

If your boot entries appear outside the `/+Arch Linux` folder or in wrong order:

1. **Clean the configuration** (backup first):

   ```bash
   sudo cp /boot/limine.conf /boot/limine.conf.backup
   # Manually remove problematic entries, keeping only basic config and entries like /Windows
   ```

2. **Regenerate entries**:

   ```bash
   sudo limine-booster-update
   ```

3. **Update snapshots** (this happens automatically during kernel removal, but can be run manually):
   ```bash
   sudo limine-snapper-sync
   ```

### Manual Operations

For manual entry management:

```bash
# Update all kernel entries
sudo limine-booster-update

# Remove specific kernel entries
sudo limine-booster-remove <package-name>

# Update snapshots (happens automatically after removal)
sudo limine-snapper-sync
```

## License

This project is licensed under the GPLv3 License - see the [LICENSE](LICENSE) file for details.
