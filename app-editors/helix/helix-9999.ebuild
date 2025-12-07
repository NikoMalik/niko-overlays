EAPI=8



LLVM_COMPAT=( {18..23} )
RUST_MIN_VER="1.82"



inherit cargo llvm-r2 optfeature  git-r3

DESCRIPTION="A post modern text editor"
HOMEPAGE="
	https://helix-editor.com/
	https://github.com/NikoMalik/helix
"
EGIT_REPO_URI="https://github.com/NikoMalik/helix.git"

LICENSE="MPL-2.0"
# Dependent crate licenses
LICENSE+="
	Apache-2.0 BSD Boost-1.0 ISC MIT MPL-2.0 MPL-2.0 Unicode-DFS-2016
	ZLIB
"
SLOT="0"
RESTRICT="test"
KEYWORDS="amd64"

IUSE="+grammar"

DEPEND="
	dev-vcs/git
"
RDEPEND="${DEPEND}"
BDEPEND="
	$(llvm_gen_dep 'llvm-core/clang:${LLVM_SLOT}=')
"

ECARGO_VENDOR="${WORKDIR}/vendor"



pkg_setup() {
	QA_FLAGS_IGNORED="
		usr/bin/hx
		usr/$(get_libdir)/${PN}/.*\.so
	"
	export HELIX_DEFAULT_RUNTIME="${EPREFIX}/usr/share/${PN}/runtime"
	use grammar || export HELIX_DISABLE_AUTO_GRAMMAR_BUILD=1
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
	cargo_src_install --path helix-term
	insinto "/usr/$(get_libdir)/${PN}"
	use grammar && doins runtime/grammars/*.so
	rm -r runtime/grammars || die
	use grammar && dosym -r "/usr/$(get_libdir)/${PN}" "/usr/share/${PN}/runtime/grammars"

	insinto /usr/share/helix
	doins -r runtime

	doicon -s 256x256 contrib/${PN}.png
	domenu contrib/Helix.desktop

	insinto /usr/share/metainfo
	doins contrib/Helix.appdata.xml

	newbashcomp contrib/completion/hx.bash hx
	newzshcomp contrib/completion/hx.zsh _hx
	dofishcomp contrib/completion/hx.fish

	DOCS=(
		README.md
		CHANGELOG.md
		docs/
	)
	HTML_DOCS=(
		book/
	)
	einstalldocs
}

pkg_postinst() {
	if ! use grammar ; then
		einfo "Grammars are not installed yet. To fetch them, run:"
		einfo ""
		einfo "  hx --grammar fetch && hx --grammar build"
	fi

	xdg_desktop_database_update
	xdg_icon_cache_update
}


src_configure() {
	cargo_src_configure --no-default-features --offline
}






