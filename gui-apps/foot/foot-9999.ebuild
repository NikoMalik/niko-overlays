EAPI=8


PYTHON_COMPAT=( python3_{10..13} )

inherit flag-o-matic meson ninja-utils python-any-r1 toolchain-funcs xdg

if [[ ${PV} != *9999* ]]; then
	SRC_URI="https://codeberg.org/dnkl/foot/archive/${PV}.tar.gz  -> ${P}.tar.gz"
	KEYWORDS="~amd64"
	S="${WORKDIR}/${PN}"
else
	inherit git-r3
	EGIT_REPO_URI="https://codeberg.org/dnkl/foot.git"
fi

BUILD_DIR="${S}/build"

DESCRIPTION="A fast, lightweight and minimalistic Wayland terminal emulator"
HOMEPAGE="https://codeberg.org/dnkl/foot"
LICENSE="MIT"
SLOT="0"
IUSE="+grapheme-clustering  pgo lto +mimalloc"

CDEPEND="
	dev-libs/wayland
	media-libs/fcft
	media-libs/fontconfig
	media-libs/freetype
	x11-libs/libxkbcommon
	x11-libs/pixman
	grapheme-clustering? (
		dev-libs/libutf8proc:=
		media-libs/fcft[harfbuzz]
	)
"
DEPEND="
	${CDEPEND}
	dev-libs/tllist
	mimalloc? ( dev-libs/mimalloc:= )

"
RDEPEND="
	${CDEPEND}
	>=sys-libs/ncurses-6.3[-minimal]
"
BDEPEND="
	app-text/scdoc
	>=dev-libs/wayland-protocols-1.32
	dev-util/wayland-scanner
	pgo? (
		|| (
			>=gui-wm/sway-1.7
		)
		${PYTHON_DEPS}
	)
"



src_compile() {
    if use pgo; then
        ./pgo/pgo.sh full-headless-sway "${S}" "${BUILD_DIR}" \
            --prefix=/usr \
            --wrap-mode=nodownload || die

		if tc-is-clang; then
			llvm-profdata merge "${BUILD_DIR}"/default_*profraw --output="${BUILD_DIR}"/default.profdata || die
		fi
		meson_src_configure -Db_pgo=use
		eninja -C "${BUILD_DIR}"
    else
        meson_src_compile
    fi
}



pkg_setup() {
	python-any-r1_pkg_setup
}

src_prepare() {
	eapply "${FILESDIR}/rss.patch"
	eapply "${FILESDIR}/mimalloc.patch"
	default
	python_fix_shebang ./scripts
}

src_configure() {
	if use pgo; then
		tc-is-clang && append-cflags -Wno-ignored-optimization-argument
	fi



	local emesonargs=(
		-Dime=true
		$(meson_feature grapheme-clustering)
		$(meson_feature mimalloc)
		-Dterminfo=disabled
		-Dthemes=true
	)
	if use lto; then
		emesonargs+=( -Db_lto=true )
	fi
	if use pgo; then
		emesonargs+=( -Db_pgo=generate )
	fi	

	
	meson_src_configure
}


src_test() {
	meson_src_configure -Dtests=true
	meson_src_test
}

src_install() {
	meson_src_install
	mv "${D}/usr/share/doc/${PN}" "${D}/usr/share/doc/${PF}" || die
}

