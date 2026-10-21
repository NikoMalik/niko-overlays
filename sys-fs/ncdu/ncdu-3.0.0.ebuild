# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

ZIG_SLOT="0.15"
ZIG_NEEDS_LLVM=1
inherit zig

DESCRIPTION="NCurses Disk Usage (NikoMalik fork)"
HOMEPAGE="https://github.com/NikoMalik/ncdu"
SRC_URI="https://github.com/NikoMalik/ncdu/archive/refs/tags/v${PV}.tar.gz -> ${P}.tar.gz"

LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64"

DEPEND="
	app-arch/zstd:=
	sys-libs/ncurses:=[unicode(+)]
"
RDEPEND="${DEPEND}"

DOCS=( "README.md" "ChangeLog" )

src_configure() {
	local my_zbs_args=(
		-Dpie=true
		--release=fast
	)

	zig_src_configure
}

src_install() {
	zig_src_install

	doman ncdu.1
}
