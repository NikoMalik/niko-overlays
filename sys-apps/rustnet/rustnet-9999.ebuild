EAPI=8



LLVM_COMPAT=( {18..23} )
RUST_MIN_VER="1.88"



inherit cargo llvm-r2 optfeature  git-r3 shell-completion xdg

DESCRIPTION="A cross-platform network monitoring tool built with Rust"
HOMEPAGE="
	https://github.com/domcyrus/rustnet
"
EGIT_REPO_URI="	https://github.com/domcyrus/rustnet.git"

LICENSE="MPL-2.0"
# Dependent crate licenses
LICENSE+="
	Apache-2.0 BSD Boost-1.0 ISC MIT MPL-2.0 MPL-2.0 Unicode-DFS-2016
	ZLIB
"
SLOT="0"
RESTRICT="test"
KEYWORDS="amd64"


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
}



src_configure() {
	cargo_src_configure --offline
}






