# Copyright 2024-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit desktop multiprocessing virtualx xdg-utils git-r3

DESCRIPTION="Welcome to a calmer internet, built from source with native optimizations"
HOMEPAGE="https://zen-browser.app"
EGIT_REPO_URI="https://github.com/zen-browser/desktop.git"
if [[ ${PV} == 9999 ]]; then
	KEYWORDS=""
else
	EGIT_COMMIT="${PV}b"
	KEYWORDS="~amd64"
fi

# Firefox base version Zen 1.22.x builds on, bump when surfer.json changes it,
# then regen Manifest. Fetched via SRC_URI so portage caches it in DISTDIR
# (the in-sandbox copy-back cannot persist under RESTRICT=network-sandbox)
FF_PV="155.0.1"
SRC_URI="https://archive.mozilla.org/pub/firefox/releases/${FF_PV}/source/firefox-${FF_PV}.source.tar.xz"

LICENSE="MPL-2.0"
SLOT="0"

IUSE="+X +full-lto +lto +pgo +wayland"
REQUIRED_USE="|| ( X wayland ) full-lto? ( lto )"

RESTRICT="network-sandbox"

DEPEND="
	app-accessibility/at-spi2-core:2
	dev-libs/expat
	dev-libs/glib:2
	dev-libs/libffi
	>=dev-libs/nspr-4.39
	>=dev-libs/nss-3.127
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
	sys-libs/zlib
	x11-libs/pixman
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
	dev-lang/python
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

	# Match www-client/firefox: strip via portage (prepstrip), not Firefox, and
	# do local PGO (MOZ_PGO=1), not Zen's CI cross-profile. Drop Zen's in-tree
	# strip settings (incl. the STRIP_FLAGS string that breaks the packager) and
	# its GA-artifact PGO profile lines (~/artifact/*.profdata does not exist here)
	local zc
	for zc in configs/common/mozconfig configs/linux/mozconfig; do
		[[ -f ${zc} ]] || continue
		sed -i -E \
			-e '/ac_add_options --enable-(install-)?strip/d' \
			-e '/export STRIP_FLAGS=/d' \
			-e '/ac_add_options --enable-profile-(generate|use)/d' \
			-e '/ac_add_options --with-pgo-(profile-path|jarlog)/d' \
		  -e '/ac_add_options --enable-optimize/d' \
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
  printf 'ac_add_options --disable-install-strip\n' >> "${mozconf}" || die
  printf 'ac_add_options --disable-strip\n' >> "${mozconf}" || die
  printf 'ac_add_options --disable-parental-controls\n' >> "${mozconf}" || die
  printf 'ac_add_options --disable-wmf\n' >> "${mozconf}" || die
  printf 'ac_add_options --enable-packed-relative-relocs\n' >> "${mozconf}" || die
  printf 'ac_add_options --disable-geckodriver\n' >> "${mozconf}" || die
  printf 'ac_add_options --disable-crashreporter\n' >> "${mozconf}" || die
  printf 'ac_add_options --allow-addon-sideload\n' >> "${mozconf}" || die
  printf 'ac_add_options --disable-legacy-profile-creation\n' >> "${mozconf}" || die





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
	if [[ ${want_ff} == ${FF_PV} ]]; then
		# portage fetched it via SRC_URI, seed it so surfer skips the ~810MB download
		cp "${DISTDIR}/firefox-${FF_PV}.source.tar.xz" .surfer/engine/ \
			|| die "Firefox ${FF_PV} not in DISTDIR (SRC_URI/Manifest issue)"
		einfo "Seeded Firefox ${FF_PV} source from DISTDIR"
	else
		ewarn "surfer.json wants Firefox ${want_ff} but FF_PV=${FF_PV}"
		ewarn "bump FF_PV in the ebuild and regen Manifest, surfer will download for now"
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

	# force sharp to build from source with its vendored libvips (8.14.5) instead
	# of the flaky prebuild-install network download that falls back to the
	# ABI-incompatible system vips, SHARP_IGNORE_GLOBAL_LIBVIPS keeps it vendored
	SHARP_IGNORE_GLOBAL_LIBVIPS=1 npm_config_build_from_source=true \
		CFLAGS="-O2 -pipe" CXXFLAGS="-O2 -pipe" npm ci || die
	npm run surfer -- ci --brand release --display-version "${zver}" || die
	npm run download || die

	npm run import || die
	sh scripts/download-language-packs.sh || die

	# Make LTO/PGO configure respect MAKEOPTS instead of multiprocessing.cpu_count()
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
	# mach build telemetry starts a Glean SDK future and waits on it in a
	# finally block (mach/main.py:493), the future never resolves in the
	# portage sandbox so mach hangs forever AFTER the build finishes, disable
	# it so _telemetry_init_done is never created
	export DISABLE_TELEMETRY=1

	# Avoid PGO profiling problems due to environment leakage (www-client/firefox),
	# a leaked session DBus/DISPLAY makes the instrumented profiling run deadlock
	unset \
		DBUS_SESSION_BUS_ADDRESS \
		DISPLAY \
		ORBIT_SOCKETDIR \
		SESSION_MANAGER \
		XAUTHORITY \
		XDG_CACHE_HOME \
		XDG_SESSION_COOKIE

	addpredict /proc/self/oom_score_adj
	if use pgo; then
		addpredict /proc
		addpredict /dev
		# tar container for the instrumented package, saves >=10 min (firefox.ebuild)
		export MOZ_PKG_FORMAT=TAR
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
