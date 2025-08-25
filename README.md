# Limine Booster

A zero-configuration, automated tool to manage Limine bootloader entries for Arch Linux kernels that use Booster.

This tool provides a pacman hook that automatically creates and updates Limine entries for all installed kernels, using the command line from your currently running system. No manual configuration is required.

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

That's it. The tool will automatically create a new entry in your `/boot/limine.conf` for the kernel you just installed. For example, after installing the `linux-lts` package, a new entry titled `/Arch Linux (linux-lts)` will be created.

### Advanced Configuration (Optional)

For most users, no configuration is needed. However, if you need to override the default behavior, you can edit `/etc/default/limine-booster.conf`.

**Override Kernel Command Line:**

By default, the script uses the command line from `/proc/cmdline`. You can specify a custom one:

```ini
# /etc/default/limine-booster.conf
CMDLINE_OVERRIDE="root=UUID=... rw quiet"
```

## License

This project is licensed under the GPLv3 License - see the [LICENSE](LICENSE) file for details.
