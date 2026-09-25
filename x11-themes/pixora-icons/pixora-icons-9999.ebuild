# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit git-r3 xdg-utils

DESCRIPTION="A 16-bit pixel-style icon theme for Linux desktops"
HOMEPAGE="https://github.com/tsora1603/pixora-icons"
EGIT_REPO_URI="https://github.com/tsora1603/pixora-icons.git"

LICENSE="GPL-3+"
SLOT="0"
KEYWORDS=""

RDEPEND="
	x11-themes/hicolor-icon-theme
	kde-frameworks/breeze-icons
"

src_install() {
	dodir /usr/share/icons
	cp -a pixora pixora-dark "${ED}"/usr/share/icons/ || die

	dodoc README.md ATTRIBUTION.md
}

pkg_postinst() {
	xdg_icon_cache_update
}

pkg_postrm() {
	xdg_icon_cache_update
}
