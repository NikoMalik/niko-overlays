
EAPI=8

ZIG_SLOT="0.15.2"
ZIG_NEEDS_LLVM=1
inherit verify-sig zig

DESCRIPTION="ls but with io_uring "
HOMEPAGE="https://github.com/NikoMalik/lsr"
SRC_URI="
	https://github.com/NikoMalik/${PN}/archive/refs/tags/v${PV}.tar.gz
"

LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64"


DOCS=( "README.md" )

src_unpack() {
	zig_src_unpack
}

src_configure() {
	local my_zbs_args=(
		-Dpie=true
		--release=fast
	)
	zig_src_configure
}

src_install() {
	zig_src_install
}
