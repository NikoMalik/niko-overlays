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

DESCRIPTION="A fast, lightweight and minimalistic Wayland terminal emulator"
HOMEPAGE="https://codeberg.org/dnkl/foot"
LICENSE="MIT"
SLOT="0"
IUSE="+grapheme-clustering pgo"

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
			gui-wm/tinywl
			gui-libs/wlroots[tinywl(-)]
		)
		${PYTHON_DEPS}
	)
"

virtwl() {
	debug-print-function ${FUNCNAME} "$@"

	[[ $# -lt 1 ]] && die "${FUNCNAME} needs at least one argument"
	[[ -n $XDG_RUNTIME_DIR ]] || die "${FUNCNAME} needs XDG_RUNTIME_DIR to be set; try xdg_environment_reset"
	tinywl -h >/dev/null || die 'tinywl -h failed'

	local VIRTWL VIRTWL_PID
	coproc VIRTWL { WLR_BACKENDS=headless exec tinywl -s 'echo $WAYLAND_DISPLAY; read _; kill $PPID'; }
	local -x WAYLAND_DISPLAY
	read WAYLAND_DISPLAY <&${VIRTWL[0]}

	debug-print "${FUNCNAME}: $@"
	"$@"
	local r=$?

	[[ -n $VIRTWL_PID ]] || die "tinywl exited unexpectedly"
	exec {VIRTWL[0]}<&- {VIRTWL[1]}>&-
	return $r
}

pkg_setup() {
	python-any-r1_pkg_setup
	export XDG_RUNTIME_DIR="${T}/run"
    mkdir -p "${XDG_RUNTIME_DIR}"
    addpredict "${XDG_RUNTIME_DIR}"
	unset \
		DBUS_SESSION_BUS_ADDRESS \
		WAYLAND_DISPLAY \
		DISPLAY \
		ORBIT_SOCKETDIR \
		SESSION_MANAGER \
		XAUTHORITY \
		XDG_CACHE_HOME \
		XDG_SESSION_COOKIE

		if use pgo ; then
			addpredict /dev/dri

			shopt -s nullglob

			for f in /dev/ati/card*; do
				addpredict "$f"
					done

			for f in /dev/dri/card*; do
				addpredict "$f"
					done

			for f in /dev/nvidia*; do
				addpredict "$f"
					done

			for f in /dev/dri/renderD128*; do
				addpredict "$f"
					done

			shopt -u nullglob
	fi
}

src_prepare() {
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
		-Dterminfo=disabled
		-Dthemes=true
	)
	if use pgo; then
		emesonargs+=( -Db_pgo=generate )
	fi
	meson_src_configure
}

src_compile() {
	meson_src_compile

	if use pgo; then
		virtwl ./pgo/full-current-session.sh "${S}" "${BUILD_DIR}"

		if tc-is-clang; then
			llvm-profdata merge "${BUILD_DIR}"/default_*profraw --output="${BUILD_DIR}"/default.profdata || die
		fi

		meson_src_configure -Db_pgo=use

		eninja -C "${BUILD_DIR}"
	fi
}

src_test() {
	xdg_environment_reset
	meson_src_configure -Dtests=true
	meson_src_test
}

src_install() {
	meson_src_install
	mv "${D}/usr/share/doc/${PN}" "${D}/usr/share/doc/${PF}" || die
}

