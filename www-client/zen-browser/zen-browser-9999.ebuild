# Copyright 2024-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

# Firefox's mach build only supports up to 3.13, list the versions it can
# use here, python-any-r1 picks the best installed one or pulls it in
PYTHON_COMPAT=( python3_{11,12,13} )

inherit desktop multiprocessing python-any-r1 virtualx xdg-utils git-r3

DESCRIPTION="Welcome to a calmer internet, built from source with native optimizations"
HOMEPAGE="https://zen-browser.app"
EGIT_REPO_URI="https://github.com/zen-browser/desktop.git"
if [[ ${PV} == 9999 ]]; then
	KEYWORDS=""
else
	EGIT_COMMIT="${PV}b"
	KEYWORDS="~amd64"
fi

LICENSE="MPL-2.0"
SLOT="0"

IUSE="+X +full-lto +lto +pgo +wayland"
REQUIRED_USE="|| ( X wayland ) full-lto? ( lto )"

RESTRICT="network-sandbox strip"

DEPEND="
	app-accessibility/at-spi2-core:2
	dev-libs/expat
	dev-libs/glib:2
	dev-libs/libffi
	dev-libs/nspr
	media-libs/alsa-lib
	media-libs/fontconfig
	media-libs/freetype
	media-libs/libepoxy
	media-libs/libpng:0=[apng]
	media-libs/mesa
	media-video/ffmpeg
	media-video/pipewire
	net-print/cups
	sys-apps/dbus
	sys-apps/pciutils
	sys-libs/glibc
	virtual/freedesktop-icon-theme
	x11-libs/cairo[X?]
	x11-libs/gdk-pixbuf:2
	x11-libs/gtk+:3[X?,wayland?]
	x11-libs/libdrm
	x11-libs/libnotify
	x11-libs/pango
	X? (
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
		x11-libs/libXScrnSaver
		x11-libs/libXtst
	)
	wayland? (
		dev-libs/wayland
		x11-libs/libxkbcommon
	)
"
RDEPEND="${DEPEND}"

BDEPEND="
	dev-vcs/git
	net-misc/curl
	${PYTHON_DEPS}
  dev-libs/libffi:=
  >=dev-libs/nss-3.127
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
	pgo? (
		llvm-runtimes/compiler-rt-sanitizers[profile]
		x11-base/xorg-server[xvfb]
	)
"

pkg_pretend() {
	if [[ ${MERGE_TYPE} != binary ]]; then
		use pgo && ewarn "PGO builds Zen twice and profile-runs it under Xvfb, expect long build time and high RAM"
		use full-lto && ewarn "full-lto: the libxul link is very RAM-heavy, on low RAM use USE=-full-lto (thin) or MAKEOPTS=-j2 plus swap"
	fi
}

src_prepare() {
	default

	local mozconf="configs/common/mozconfig"
	[[ -f ${mozconf} ]] || die "mozconfig template not found at ${mozconf}"

	# Zen's own mozconfigs hardcode LTO (common=thin, linux=full), CI-only
	# GA-artifact PGO (~/artifact/*.profdata), elf-hack disable and a
	# STRIP_FLAGS string that breaks Firefox's packager, strip all of these
	# so our USE-driven options below are authoritative
	local zc
	for zc in configs/common/mozconfig configs/linux/mozconfig; do
		[[ -f ${zc} ]] || continue
		sed -i -E \
			-e '/ac_add_options --enable-lto/d' \
			-e '/export MOZ_LTO=/d' \
			-e '/ac_add_options --enable-profile-(generate|use)/d' \
			-e '/ac_add_options --with-pgo-(profile-path|jarlog)/d' \
			-e '/ac_add_options --(enable|disable)-elf-hack/d' \
			-e '/export STRIP_FLAGS=/d' \
			"${zc}" || die "failed to sanitize ${zc}"
	done

	# use system clang/llvm instead of a bootstrapped mozbuild toolchain
	printf '\nac_add_options --disable-bootstrap\n' >> "${mozconf}" || die
	printf 'ac_add_options --with-libclang-path=%s\n' "$(llvm-config --libdir)" >> "${mozconf}" || die
	printf 'ac_add_options --without-wasm-sandboxed-libraries\n' >> "${mozconf}" || die
	printf 'ac_add_options --disable-clang-plugin\n' >> "${mozconf}" || die
	printf 'ac_add_options --disable-updater\n' >> "${mozconf}" || die
	printf 'ac_add_options --disable-cargo-incremental\n' >> "${mozconf}" || die
  printf 'ac_add_options --enable-optimize=-O3\n' >> "${mozconf}" || die
  printf 'ac_add_options --enable-linker=lld\n' >> "${mozconf}" || die
  printf 'ac_add_options --enable-install-strip\n' >> "${mozconf}" || die
  printf 'ac_add_options --enable-strip\n' >> "${mozconf}" || die
  printf 'ac_add_options --disable-parental-controls\n' >> "${mozconf}" || die

  printf 'ac_add_options --without-ccache\n' >> "${mozconf}" || die
  printf 'ac_add_options --with-intl-api\n' >> "${mozconf}" || die
  printf 'ac_add_options --with-system-ffi\n' >> "${mozconf}" || die
  printf 'ac_add_options --with-system-gbm\n' >> "${mozconf}" || die
  printf 'ac_add_options --with-system-libdrm\n' >> "${mozconf}" || die
  printf 'ac_add_options --with-system-nspr\n' >> "${mozconf}" || die
  printf 'ac_add_options --with-system-nss\n' >> "${mozconf}" || die
  printf 'ac_add_options --with-system-pixman\n' >> "${mozconf}" || die
  printf 'ac_add_options --with-system-zlib\n' >> "${mozconf}" || die
  printf 'ac_add_options --with-unsigned-addon-scopes=app,system\n' >> "${mozconf}" || die
  printf 'ac_add_options --enable-elf-hack=relr\n' >> "${mozconf}" || die



		









	local toolkit
	if use X && use wayland; then
		toolkit="cairo-gtk3-x11-wayland"
	elif use wayland; then
		toolkit="cairo-gtk3-wayland-only"
	else
		toolkit="cairo-gtk3-x11-only"
	fi
	printf 'ac_add_options --enable-default-toolkit=%s\n' "${toolkit}" >> "${mozconf}" || die

	if use pgo; then
		printf 'ac_add_options MOZ_PGO=1\nmk_add_options MOZ_PGO=1\n' >> "${mozconf}" || die
	fi

	if use lto; then
		local ltotype=cross,thin
		use full-lto && ltotype=cross,full
		printf 'ac_add_options --enable-lto=%s\nmk_add_options MOZ_LTO=%s\n' "${ltotype}" "${ltotype}" >> "${mozconf}" || die
	else
		printf 'ac_add_options --disable-lto\n' >> "${mozconf}" || die
	fi



	local want_ff
	want_ff=$(python3 -c \
		"import json;print(json.load(open('surfer.json'))['version']['version'])" 2>/dev/null) \
		|| die "cannot read Firefox version from surfer.json"

	mkdir -p .surfer/engine || die
	if [[ -f ${DISTDIR}/firefox-${want_ff}.source.tar.xz ]]; then
		cp "${DISTDIR}/firefox-${want_ff}.source.tar.xz" .surfer/engine/ || die
		einfo "Seeded Firefox ${want_ff} source from cache"
	else
		einfo "Firefox ${want_ff} source not cached, surfer will download it"
	fi
}

src_configure() {
	local want wantmaj nodever havemaj
	want=$(<.nvmrc)
	wantmaj=${want%%.*}
	nodever=$(node --version 2>/dev/null)
	havemaj=${nodever#v}
	havemaj=${havemaj%%.*}
	if [[ -z ${havemaj} ]]; then
		die "Node.js not found, install >=net-libs/nodejs-${wantmaj}"
	elif [[ ${havemaj} -lt ${wantmaj} ]]; then
		die "Zen needs Node.js >=${wantmaj} (.nvmrc wants ${want}), active node is ${nodever}"
	elif [[ ${havemaj} -ne ${wantmaj} ]]; then
		ewarn "Zen upstream pins Node.js ${want} (.nvmrc), building with ${nodever}"
		ewarn "if surfer or npm fails, install net-libs/nodejs-${wantmaj} and retry"
	fi

	local zver
	zver=$(python3 -c \
		"import json;print(json.load(open('surfer.json'))['brands']['release']['release']['displayVersion'])") \
		|| die "cannot read displayVersion from surfer.json"

	SHARP_IGNORE_GLOBAL_LIBVIPS=1 CFLAGS="-O2 -pipe" CXXFLAGS="-O2 -pipe" npm ci || die
	npm run surfer -- ci --brand release --display-version "${zver}" || die
	npm run download || die

	local ffsrc
	ffsrc=$(echo .surfer/engine/firefox-*.source.tar.xz)
	if [[ -f ${ffsrc} && ! -f ${DISTDIR}/${ffsrc##*/} ]]; then
		addwrite "${DISTDIR}"
		cp "${ffsrc}" "${DISTDIR}/" 2>/dev/null || ewarn "could not cache Firefox source into ${DISTDIR}"
	fi

	npm run import || die
	sh scripts/download-language-packs.sh || die

	# mach's PGO/LTO configure calls multiprocessing.cpu_count(), whose pool
	# deadlocks on a futex in the portage sandbox, replace it with a fixed
	# job count like www-client/firefox does (source now exists under engine/)
	local f
	for f in \
		engine/build/moz.configure/lto-pgo.configure \
		engine/third_party/chromium/build/toolchain/get_cpu_count.py \
		engine/third_party/python/gyp/pylib/gyp/input.py ; do
		[[ -f ${f} ]] && { sed -i -e "s/multiprocessing.cpu_count()/$(makeopts_jobs)/" "${f}" || die "failed sedding ${f}"; }
	done
}

src_compile() {
	export ZEN_RELEASE=1
	export CC=clang
	export CXX=clang++
	export AR=llvm-ar
	export NM=llvm-nm
	export RANLIB=llvm-ranlib
	export LLVM_PROFDATA=llvm-profdata
	export MACH_BUILD_PYTHON_NATIVE_PACKAGE_SOURCE=none
	export PIP_NETWORK_INSTALL_RESTRICTED_VIRTUALENVS=mach
	export MOZBUILD_STATE_PATH="${WORKDIR}/.mozbuild"
	export MOZ_MAKE_FLAGS="${MAKEOPTS}"
	export MOZ_NOSPAM=1
	export XARGS="${EPREFIX}/usr/bin/xargs"
	export RUSTC_OPT_LEVEL=3

	# Firefox 155's mach build hangs under Python 3.14, force the interpreter
	# python-any-r1 selected (${EPYTHON}, e.g. 3.13) via a PATH shim, resolve
	# the real binary so 'python3' does not re-dispatch through python-exec
	local realpy pyshim="${T}/pyshim"
	realpy=$("${PYTHON}" -c 'import sys, os; print(os.path.realpath(sys.executable))') \
		|| die "cannot resolve ${EPYTHON} interpreter"
	mkdir -p "${pyshim}" || die
	ln -sf "${realpy}" "${pyshim}/python3" || die
	ln -sf "${realpy}" "${pyshim}/python" || die
	export PATH="${pyshim}:${PATH}"

	addpredict /proc/self/oom_score_adj
	if use pgo; then
		addpredict /proc
		addpredict /dev
	fi

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
