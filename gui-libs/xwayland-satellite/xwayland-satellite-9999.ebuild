EAPI=8


CRATES=""

LLVM_COMPAT=( {17..20} )

RUST_NEEDS_LLVM=1

inherit llvm-r1 cargo

DESCRIPTION="Xwayland outside your Wayland"
HOMEPAGE="https://github.com/NikoMalik/xwayland-satellite"
SRC_URI="https://github.com/NikoMalik/${PN}/archive/refs/tags/${PV}.tar.gz -> ${P}.tar.gz"
DEPS_URI="https://github.com/NikoMalik/${PN}/releases/download/${PV}/${P}-crates.tar.xz"
SRC_URI+=" ${DEPS_URI}"

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

QA_FLAGS_IGNORED="usr/bin/${PN}"

pkg_setup() {
	llvm-r1_pkg_setup
	rust_pkg_setup
}


src_unpack() {
	cargo_src_unpack

        if [[ -f "${DISTDIR}/${P}-crates.tar.xz" ]]; then
                mkdir -p "${CARGO_HOME}/vendor"
                tar -xf "${DISTDIR}/${P}-crates.tar.xz" -C "${CARGO_HOME}/vendor" --strip-components=1 || die "Failed to unpack crates"
        fi
}



src_prepare() {
        default

        cat <<-EOF > "${S}/.cargo/config.toml"
[source.crates-io]
replace-with = "vendored-sources"

[source.vendored-sources]
directory = "${CARGO_HOME}/vendor"
EOF

        mkdir -p "${S}/vendor"
        ln -sf "${CARGO_HOME}/vendor" "${S}/vendor/vendored" 2>/dev/null || true
}

src_install() {
	cargo_src_install --locked
	einstalldocs
}




