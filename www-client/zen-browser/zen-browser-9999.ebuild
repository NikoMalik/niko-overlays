# Copyright 2024-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit desktop virtualx xdg-utils git-r3

DESCRIPTION="Welcome to a calmer internet, built from source with native optimizations"
HOMEPAGE="https://zen-browser.app"
EGIT_REPO_URI="https://github.com/zen-browser/desktop.git"

FF_PV="155.0"
SRC_URI="https://archive.mozilla.org/pub/firefox/releases/${FF_PV}/source/firefox-${FF_PV}.source.tar.xz"

LICENSE="MPL-2.0"
SLOT="0"
KEYWORDS=""

IUSE="+lto +native +pgo +wayland"

RESTRICT="network-sandbox strip"

DEPEND="
	app-accessibility/at-spi2-core:2
	dev-libs/expat
	dev-libs/glib:2
	dev-libs/nspr
	dev-libs/nss
	media-libs/alsa-lib
	media-libs/fontconfig
	media-libs/freetype
	media-libs/libpng:0=[apng]
	media-libs/mesa
	media-video/ffmpeg
	net-print/cups
	sys-apps/dbus
	sys-libs/glibc
	virtual/freedesktop-icon-theme
	x11-libs/cairo[X]
	x11-libs/gdk-pixbuf:2
	x11-libs/gtk+:3[X]
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
	wayland? ( dev-libs/wayland )
"
RDEPEND="${DEPEND}"

BDEPEND="
	dev-vcs/git
	net-misc/curl
	dev-lang/python
	>=net-libs/nodejs-22.13.1[npm]
	|| (
		>=dev-lang/rust-bin-1.94.1
		>=dev-lang/rust-1.94.1
	)
	dev-util/cbindgen
	llvm-core/clang
	llvm-core/llvm
	llvm-core/lld
	dev-lang/nasm
	dev-lang/yasm
	virtual/pkgconfig
"

pkg_pretend() {
	if use pgo && [[ ${MERGE_TYPE} != binary ]]; then
		ewarn "PGO builds Zen twice and profile-runs it under Xvfb, expect long build time and high RAM"
	fi
}

src_prepare() {
	default

	local mozconf="configs/common/mozconfig"
	[[ -f ${mozconf} ]] || die "mozconfig template not found at ${mozconf}"

	# use system clang/llvm instead of a bootstrapped mozbuild toolchain
	printf '\nac_add_options --disable-bootstrap\n' >> "${mozconf}" || die
	printf 'ac_add_options --with-libclang-path=%s\n' "$(llvm-config --libdir)" >> "${mozconf}" || die
	printf 'ac_add_options --without-wasm-sandboxed-libraries\n' >> "${mozconf}" || die
	printf 'ac_add_options --disable-clang-plugin\n' >> "${mozconf}" || die
	printf 'ac_add_options --disable-updater\n' >> "${mozconf}" || die
	printf 'ac_add_options --disable-cargo-incremental\n' >> "${mozconf}" || die

	if use native; then
		printf 'ac_add_options --enable-optimize="-O3 -march=native -fomit-frame-pointer  -fno-plt "\n' >> "${mozconf}" || die
	fi

	if use wayland; then
		printf 'ac_add_options --enable-default-toolkit=cairo-gtk3-wayland\n' >> "${mozconf}" || die
	fi

	if use pgo; then
		printf 'ac_add_options MOZ_PGO=1\nmk_add_options MOZ_PGO=1\n' >> "${mozconf}" || die
	fi

	local want_ff
	want_ff=$(python3 -c \
		"import json;print(json.load(open('surfer.json'))['version']['version'])" 2>/dev/null)
	if [[ -n ${want_ff} && ${want_ff} != ${FF_PV} ]]; then
		ewarn "Zen wants Firefox ${want_ff} but FF_PV is ${FF_PV}, cache bypassed, bump FF_PV in the ebuild"
	fi

	mkdir -p .surfer/engine || die
	cp "${DISTDIR}/firefox-${FF_PV}.source.tar.xz" .surfer/engine/ || die
}

src_configure() {
	local want nodever
	want=$(<.nvmrc)
	nodever=$(node --version 2>/dev/null)
	if [[ ${nodever} != v${want}.* ]]; then
		die "Zen needs Node.js ${want} (.nvmrc), active node is ${nodever:-none}, install and select net-libs/nodejs-${want}"
	fi

	local zver
	zver=$(python3 -c \
		"import json;print(json.load(open('surfer.json'))['brands']['release']['release']['displayVersion'])") \
		|| die "cannot read displayVersion from surfer.json"

	SHARP_IGNORE_GLOBAL_LIBVIPS=1 CFLAGS="-O2 -pipe" CXXFLAGS="-O2 -pipe" npm ci || die
	npm run surfer -- ci --brand release --display-version "${zver}" || die
	npm run download || die
	npm run import || die
	sh scripts/download-language-packs.sh || die
}

src_compile() {
	export ZEN_RELEASE=1
	export CC=clang
	export CXX=clang++
	export LLVM_PROFDATA=llvm-profdata
	export MACH_BUILD_PYTHON_NATIVE_PACKAGE_SOURCE=none
	export PIP_NETWORK_INSTALL_RESTRICTED_VIRTUALENVS=mach
	export MOZBUILD_STATE_PATH="${WORKDIR}/.mozbuild"
	export XARGS="${EPREFIX}/usr/bin/xargs"

	use lto || export ZEN_DISABLE_LTO=1

	virtx npm run build
}

src_install() {
	local bindir
	bindir=$(echo engine/obj-*/dist/bin)
	[[ -d ${bindir} ]] || die "build output not found at ${bindir}"

	local destdir="/opt/zen-browser"
	dodir "${destdir}"
	cp -RL "${bindir}"/. "${ED}${destdir}"/ || die

	dosym -r "${destdir}/zen" /usr/bin/zen || die

	local size
	for size in 16 32 48 64 128; do
		local icon="${bindir}/browser/chrome/icons/default/default${size}.png"
		[[ -f ${icon} ]] && newicon -s ${size} "${icon}" zen.png
	done

	make_desktop_entry "/usr/bin/zen %u" "Zen Browser" zen \
		"Network;WebBrowser" "$(cat "${FILESDIR}"/desktop_options)"

	local bin
	for bin in zen-bin updater glxtest vaapitest; do
		[[ -f ${ED}${destdir}/${bin} ]] && fperms 0755 "${destdir}/${bin}"
	done
	[[ -f ${ED}${destdir}/pingsender ]] && fperms 0750 "${destdir}/pingsender"

	insinto "${destdir}"/distribution
	doins "${FILESDIR}"/policies.json
}

pkg_postinst() {
	xdg_desktop_database_update
	xdg_icon_cache_update
}

pkg_postrm() {
	xdg_desktop_database_update
	xdg_icon_cache_update
}
