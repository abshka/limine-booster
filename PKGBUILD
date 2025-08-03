# Maintainer: Alexander Belov <markelofaleksei@gmail.com>
pkgname=limine-booster
pkgver=2.1.0
pkgrel=1
pkgdesc="Zero-config automation for Limine boot entries with Booster"
arch=('any')
url="https://github.com/abshka/limine-booster"
license=('GPL3')
depends=('booster' 'limine')
optdepends=('intel-ucode: For automatic detection of Intel microcode'
            'amd-ucode: For automatic detection of AMD microcode')
source=("$url/archive/v$pkgver.tar.gz")
sha256sums=('SKIP')

package() {
    cd "$pkgname-$pkgver"
    install -Dm755 "limine-booster-update" "$pkgdir/usr/bin/limine-booster-update"
    install -Dm644 "limine-booster.conf" "$pkgdir/etc/default/limine-booster.conf"
    install -Dm644 "91-limine-booster.hook" "$pkgdir/usr/share/libalpm/hooks/91-limine-booster.hook"
}
