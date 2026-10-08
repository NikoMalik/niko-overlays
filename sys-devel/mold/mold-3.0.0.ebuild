# Copyright 2021-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2


EAPI=8

CRATES="
	allocator-api2@0.2.21
	arrayvec@0.7.8
	blake3@1.8.7
	bstr@1.13.1
	cc@1.4.4
	cfg-if@1.0.4
	constant_time_eq@0.4.2
	cpp_demangle@0.4.5
	cpufeatures@0.3.1
	crc32fast@1.5.1
	crossbeam-deque@0.8.7
	crossbeam-epoch@0.9.20
	crossbeam-utils@0.8.22
	either@1.18.0
	equivalent@1.0.2
	find-msvc-tools@0.1.11
	flate2@1.1.10
	foldhash@0.2.0
	getrandom@0.4.3
	hashbrown@0.17.1
	jobserver@0.1.35
	libc@0.2.189
	libz-sys@1.1.29
	memchr@2.8.3
	memmap2@0.9.11
	pkg-config@0.3.34
	portable-atomic@1.15.0
	proc-macro2@1.0.107
	quote@1.0.47
	r-efi@6.0.0
	rayon-core@1.13.0
	rayon@1.12.0
	regex-automata@0.4.18
	rustc-demangle@0.1.28
	serde_core@1.0.229
	serde_derive@1.0.229
	shlex@2.0.1
	syn@3.0.4
	unicode-ident@1.0.24
	uuid@1.27.0
	vcpkg@0.2.15
	xxhash-rust@0.8.18
	zstd-safe@7.2.4
	zstd-sys@2.0.16+zstd.1.5.7
	zstd@0.13.3
"

declare -A GIT_CRATES=(
	[libmimalloc-sys]='https://github.com/rui314/mimalloc_rust;3979460494f1cd1e7f936cb8e10f41e927c9f698;mimalloc_rust-%commit%/libmimalloc-sys'
	[mimalloc]='https://github.com/rui314/mimalloc_rust;3979460494f1cd1e7f936cb8e10f41e927c9f698;mimalloc_rust-%commit%'
)

# mimalloc_rust carries mimalloc as a git submodule, which the GitHub archive
# of the crate leaves empty. libmimalloc-sys compiles it unconditionally, even
# with the system-allocator feature, so the pinned submodule commit (mimalloc
# 3.5.3, read from the fork at the GIT_CRATES commit) ships as its own distfile.
MIMALLOC_COMMIT="d4881d338125e1cb7c47ba4cfb398d6f7c0c8d45"
MIMALLOC_RUST_COMMIT="3979460494f1cd1e7f936cb8e10f41e927c9f698"

RUST_MIN_VER="1.95.0"

inherit cargo toolchain-funcs

DESCRIPTION="A Modern Linker"
HOMEPAGE="https://github.com/rui314/mold"
SRC_URI="
	https://github.com/rui314/mold/archive/refs/tags/v${PV}.tar.gz -> ${P}.tar.gz
	https://github.com/microsoft/mimalloc/archive/${MIMALLOC_COMMIT}.tar.gz
		-> mimalloc-${MIMALLOC_COMMIT}.tar.gz
	${CARGO_CRATE_URIS}
"

LICENSE="MIT"
# Dependent crate licenses
LICENSE+="
	Boost-1.0 MIT Unicode-3.0 ZLIB
	|| ( Apache-2.0 Apache-2.0-with-LLVM-exceptions CC0-1.0 )
	|| ( Apache-2.0 CC0-1.0 MIT-0 )
"
SLOT="0"
# https://github.com/rui314/mold/commit/3711ddb95e23c12991f6b8c7bfeba4f1421d19d4
KEYWORDS="-alpha ~amd64 ~arm ~arm64 ~loong ~ppc ~riscv ~sparc ~x86"
IUSE="mimalloc test"
RESTRICT="!test? ( test )"

RDEPEND="
	app-arch/zstd:=
	virtual/zlib:=
"
DEPEND="${RDEPEND}"
BDEPEND="
	virtual/pkgconfig
	test? ( llvm-core/clang:* )
"

src_prepare() {
	local mimalloc_dir="${WORKDIR}/mimalloc_rust-${MIMALLOC_RUST_COMMIT}/libmimalloc-sys/c_src/mimalloc/v3"
	rmdir "${mimalloc_dir}" || die
	mv "${WORKDIR}/mimalloc-${MIMALLOC_COMMIT}" "${mimalloc_dir}" || die

	default

	# Needs unpackaged dwarfdump
	rm tests/{{dead,compress}-debug-sections,compressed-debug-info}.sh || die

	# Heavy tests, need qemu
	rm tests/gdb-index-{compress-output,dwarf{2,3,4,5}}.sh || die
	rm tests/lto-{archive,dso,gcc,llvm,version-script}.sh || die

	# Sandbox sadness
	rm tests/run.sh || die
	sed -i 's|`pwd`/mold-wrapper.so|"& ${LD_PRELOAD}"|' \
		tests/mold-wrapper{,2}.sh || die

	# Fails if binutils errors out on textrels by default
	rm tests/textrel.sh tests/textrel2.sh || die

	# Don't let the default linker config affect the tests, bug #974439
	sed -e 's:\(clang\|clang\+\+\):\1 --no-default-config:' -i tests/*.sh || die

	# static-pie tests require glibc built with static-pie support
	if ! has_version -d 'sys-libs/glibc[static-pie(+)]'; then
		rm tests/{,ifunc-}static-pie.sh || die
	fi
}

src_configure() {
	# Baked in at build time: where `mold -run` looks for mold-wrapper.so.
	export MOLD_LIBDIR="${EPREFIX}/usr/$(get_libdir)"
	export ZSTD_SYS_USE_PKG_CONFIG=1

	# All targets stay enabled (upstream's default feature set): a linker
	# only for the host arch would break cross toolchains.
	local myfeatures=(
		$(usev !mimalloc system-allocator)
	)
	cargo_src_configure
}

src_compile() {
	# --workspace: the root package alone does not build the mold binary,
	# which lives in the cli/ member.
	cargo_src_compile --workspace
}

src_test() {
	export TEST_CC="$(tc-getCC)" TEST_GCC="$(tc-getCC)" \
		TEST_CXX="$(tc-getCXX)" TEST_GXX="$(tc-getCXX)"
	cargo_src_test --workspace
}

src_install() {
	local out="$(cargo_target_dir)"

	dobin "${out}"/${PN}

	# https://bugs.gentoo.org/872773
	insinto /usr/$(get_libdir)/mold
	doins "${out}"/${PN}-wrapper.so

	dodoc docs/${PN}.md
	doman docs/${PN}.1

	dosym ${PN} /usr/bin/ld.${PN}
	dosym ${PN} /usr/bin/ld64.${PN}
	dosym ${PN}.1 /usr/share/man/man1/ld.${PN}.1
	dosym -r /usr/bin/${PN} /usr/libexec/${PN}/ld
}
