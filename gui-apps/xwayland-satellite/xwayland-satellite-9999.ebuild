EAPI=8



LLVM_COMPAT=( {18..23} )
RUST_MIN_VER="1.80.1"



inherit cargo llvm-r2 optfeature  git-r3

DESCRIPTION="Xwayland outside your Wayland"
HOMEPAGE="https://github.com/Supreeeme/xwayland-satellite"
EGIT_REPO_URI="https://github.com/NikoMalik/xwayland-satellite.git"

LICENSE="MPL-2.0 Apache-2.0 BSD ISC MIT Unicode-DFS-2016 ZLIB"
SLOT="0"
RESTRICT="test"

DEPEND="
	>=x11-base/xwayland-23.1
	x11-libs/libxcb
	x11-libs/xcb-util-cursor
"
RDEPEND="${DEPEND}"
BDEPEND="
	$(llvm_gen_dep 'llvm-core/clang:${LLVM_SLOT}=')
"

ECARGO_VENDOR="${WORKDIR}/vendor"


QA_FLAGS_IGNORED="usr/bin/${PN}"

pkg_setup() {
	llvm-r2_pkg_setup
	rust_pkg_setup

}


src_unpack() {
	git-r3_src_unpack
	default
	cd "${WORKDIR}/${P}"
	cargo update
	cd "${WORKDIR}"
	cargo_live_src_unpack
}



src_prepare() {
	sed -i 's/git = "[^ ]*"/version = "*"/' Cargo.toml || die
	default
}

src_install() {
	cargo_src_install
	einstalldocs
}


src_configure() {
	cargo_src_configure  --offline
}





