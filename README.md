# Limine Booster

A zero-configuration, automated tool to manage Limine bootloader entries for Arch Linux kernels with support for both Booster and mkinitcpio initramfs.

This tool provides a pacman hook that automatically creates and updates Limine entries for all installed kernels, using the command line from your currently running system. No manual configuration is required.

The generated entries are fully compatible with `limine-snapper-sync` for BTRFS snapshot management, including automatic OS detection via machine-id.

## Features

- **Zero-Configuration:** Works out of the box. No need to edit config files after installation.
- **Fully Automated:** A pacman hook handles everything automatically when you install, upgrade, or remove any kernel.
- **Multi-Kernel Support:** Automatically creates and manages separate entries for all installed kernels (e.g., `linux`, `linux-lts`, `linux-zen`).
- **Smart Hook Logic:** Intelligently processes only changed kernels or all kernels based on the type of update.
- **Automatic Cleanup:** Removes entries when kernel packages are uninstalled.
- **Smart Cmdline Detection:** Uses the command line from your running system (`/proc/cmdline`) for new entries.
- **Automatic Microcode Detection:** Includes Intel/AMD microcode with proper ordering for optimal boot performance.
- **Optimized Entry Positioning:** Places new kernel entries at the top of boot menu for better visibility and compatibility.

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
- Sub-entries for each kernel: `//kernel-name kernel-version (initramfs-type)`

For example, after installing the `linux-lts` package with both Booster and mkinitcpio available, you'll see:

```
/+Arch Linux
    comment: machine-id=your-machine-id

//linux-lts 6.6.52-1-lts (Booster)
    protocol: linux
    comment: Auto-generated for linux-lts 6.6.52-1-lts (Booster)
    kernel_path: boot():/machine-id/linux-lts/vmlinuz-linux-lts
    module_path: boot():/intel-ucode.img
    module_path: boot():/machine-id/linux-lts/booster-linux-lts.img
    kernel_cmdline: your-kernel-parameters

//linux-lts 6.6.52-1-lts (mkinitcpio)
    protocol: linux
    comment: Auto-generated for linux-lts 6.6.52-1-lts (mkinitcpio)
    kernel_path: boot():/machine-id/linux-lts/vmlinuz-linux-lts
    module_path: boot():/intel-ucode.img
    module_path: boot():/machine-id/linux-lts/initramfs-linux-lts.img
    kernel_cmdline: your-kernel-parameters
```

### limine-snapper-sync Compatibility

The generated format is fully compatible with `limine-snapper-sync`:

- **Machine-ID Detection**: The main entry includes `comment: machine-id=<machine-id>` which allows `limine-snapper-sync` to automatically target the correct OS entry regardless of the OS name configuration.
- **Proper Module Order**: Microcode is placed after the kernel and before the initramfs for optimal boot performance.
- **Snapshot Integration**: The `/+` prefix enables automatic BTRFS snapshot functionality.

### Advanced Configuration (Optional)

For most users, no configuration is needed. However, if you need to override the default behavior, you can edit `/etc/default/limine-booster.conf`.

**Override Kernel Command Line:**

By default, the script uses the command line from `/proc/cmdline`. You can specify a custom one:

```ini
# /etc/default/limine-booster.conf
CMDLINE_OVERRIDE="root=UUID=... rw quiet"
```

**Control Initramfs Types:**

You can control which initramfs types to generate entries for:

```ini
# Generate entries for both booster and mkinitcpio (default)
INITRAMFS_TYPES="auto"

# Only generate Booster entries
INITRAMFS_TYPES="booster"

# Only generate mkinitcpio entries
INITRAMFS_TYPES="mkinitcpio"

# Force both types (even if one is missing)
INITRAMFS_TYPES="both"
```

**Entry Naming:**

Control whether initramfs type is appended to entry names:

```ini
# Append type when multiple initramfs available (default)
APPEND_INITRAMFS_TYPE="yes"

# Use simple names (may cause conflicts)
APPEND_INITRAMFS_TYPE="no"
```

## Migration from limine-mkinitcpio-hook

If you have `limine-mkinitcpio-hook` installed, you should remove it to avoid conflicts:

```bash
sudo pacman -R limine-mkinitcpio-hook
```

The unified `limine-booster` now handles both Booster and mkinitcpio initramfs generation automatically.

## Troubleshooting

### limine-snapper-sync Errors

When running `limine-snapper-sync`, you may see these errors:

```
bash: line 1: limine-reset-enroll: command not found
bash: line 1: limine-enroll-config: command not found
```

These errors can be **safely ignored**. They occur because some optional limine-snapper-sync components are not installed, but the core snapshot functionality works perfectly. The important message is:

```
Saved successfully: /boot/limine.conf
```

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

3. **Run limine-snapper-sync** to update snapshots:
   ```bash
   sudo limine-snapper-sync
   ```

## License

This project is licensed under the GPLv3 License - see the [LICENSE](LICENSE) file for details.
