# Limine Booster Manager

A simple, automated tool to manage Limine bootloader entries for Arch Linux kernels that use Booster instead of mkinitcpio.

This tool provides a pacman hook that automatically regenerates the Booster image and updates a dedicated Limine entry whenever a specified kernel package is installed or upgraded.

## Features

-   Fully automated updates via pacman hooks.
-   Configurable to target any kernel package (e.g., `linux`, `linux-lts`, `linux-zen`).
-   Automatically detects and includes Intel/AMD microcode.
-   Clean, single-purpose script with no external dependencies besides `booster` and `limine`.

## Installation

Install the package from the Arch User Repository (AUR). For example, using `yay`:

```bash
yay -S limine-booster
```

## Setup

After installation, you need to perform three simple steps:

**1. Configure the package:**

Edit `/etc/default/limine-booster.conf` to specify which kernel package you want to manage.

```ini
# /etc/default/limine-booster.conf
TARGET_KERNEL_PACKAGE="linux-cachyos-rc"
```

**2. Create a Limine boot entry:**

Add a new, dedicated entry to your `/boot/limine.conf`. The title must exactly match `TARGET_ENTRY_NAME` from your config file.

```ini
# /boot/limine.conf
/Arch Linux (Booster)
    comment: This entry is managed by limine-booster-manager
    protocol: linux
    # The script will automatically populate the paths below.
```

**3. Run the update script manually:**

This will perform the initial setup, generate the first Booster image, and populate your new Limine entry.

```bash
sudo limine-booster-update
```

That's it! From now on, the process is fully automated.

## License

This project is licensed under the GPLv3 License - see the [LICENSE](LICENSE) file for details.
