# Maintainer: Alexander Belov <markelofaleksei@gmail.com>
#
# This PKGBUILD is intended for building directly from a cloned Git repository.
# It uses local files as sources. For the AUR version, see PKGBUILD.aur.
#

# To match the repository name, it's good practice to use the same pkgname.
pkgname=limine-booster
pkgver=1.1.0
pkgrel=1
pkgdesc="Automates Limine bootloader entries for kernels using Booster"
arch=('any')
url="https://github.com/abshka/limine-booster"
license=('GPL3')
depends=('booster' 'limine')
optdepends=('intel-ucode: For automatic detection and inclusion of Intel microcode'
            'amd-ucode: For automatic detection and inclusion of AMD microcode')
install="${pkgname}.install"

# The source array points to the local files in the repository.
# The .install script is handled by the 'install=' line and is not listed here.
source=("limine-booster-update"
        "limine-booster.conf"
        "91-limine-booster.hook")

# For local sources, checksums can be skipped for convenience.
sha256sums=('SKIP'
            'SKIP'
            'SKIP')

# The package() function installs files from the src/ directory,
# where makepkg copies the local source files.
package() {
    # Install the main script with execute permissions
    install -Dm755 "$srcdir/limine-booster-update" "$pkgdir/usr/bin/limine-booster-update"

    # Install the default configuration file
    install -Dm644 "$srcdir/limine-booster.conf" "$pkgdir/etc/default/limine-booster.conf"

    # Install the pacman hook
    install -Dm644 "$srcdir/91-limine-booster.hook" "$pkgdir/usr/share/libalpm/hooks/91-limine-booster.hook"
}

# vim: set ts=4 sw=4 et:
