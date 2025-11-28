EAPI=8


EPYTHON=/usr/bin/python
PYTHON_COMPAT=( python3_{10..13} )

inherit git-r3

RESTRICT="network-sandbox sandbox userpriv"

DESCRIPTION="Welcome to a calmer internet "
HOMEPAGE="https://zen-browser.app"

EGIT_REPO_URI="https://github.com/zen-browser/desktop.git"

LICENSE="MPL-2.0"
SLOT="0"
KEYWORDS="~amd64 ~arm64"
RESTRICT="strip"

DEPEND="
	app-accessibility/at-spi2-core:2
	dev-libs/expat
	dev-libs/glib:2
	dev-libs/nspr
	dev-libs/nss
	media-libs/alsa-lib
	media-libs/fontconfig
	media-libs/freetype
	media-libs/mesa
	net-print/cups
	sys-apps/dbus
	sys-libs/glibc
	x11-libs/cairo
	x11-libs/gdk-pixbuf:2
	x11-libs/gtk+:3
	x11-libs/libX11
	x11-libs/libxcb
	x11-libs/libXcomposite
	x11-libs/libXcursor
	x11-libs/libXdamage
	x11-libs/libXext
	x11-libs/libXfixes
	x11-libs/libXi
	x11-libs/libXrandr
	x11-libs/libXrender
	x11-libs/libXtst
	x11-libs/pango
"
RDEPEND=${DEPEND}

BDEPEND="dev-vcs/git
         net-misc/curl
         dev-lang/python
         dev-python/pip
         net-libs/nodejs[npm]
         dev-util/cbindgen
         dev-util/bindgen"


src_prepare() {
    npm i || die
    npm run init || die
    python ./scripts/update_en_US_packs.py || die
    npm run bootstrap || die
    eapply_user
}

src_compile() {
    npm run build --with-libclang-path="$(llvm-config --libdir)" || die
}
