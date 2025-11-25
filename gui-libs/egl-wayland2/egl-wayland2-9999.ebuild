EAPI=8

inherit meson-multilib git-r3

DESCRIPTION="NVIDIA wayland EGL external platform library, git version"
HOMEPAGE="https://github.com/NVIDIA/egl-wayland2/"
EGIT_REPO_URI="https://github.com/NVIDIA/egl-wayland2.git"

LICENSE="Apache-2.0"
SLOT="0"
KEYWORDS=""

RDEPEND="
	dev-libs/wayland[${MULTILIB_USEDEP}]
	media-libs/mesa[gbm(+),${MULTILIB_USEDEP}]
	x11-libs/libdrm[${MULTILIB_USEDEP}]
"

DEPEND="
	${RDEPEND}
	>=dev-libs/wayland-protocols-1.38
	>=gui-libs/eglexternalplatform-1.2
	media-libs/libglvnd
"

BDEPEND="
	dev-util/wayland-scanner
"


pkg_postinst() {
	ewarn "gui-libs/egl-wayland2 (git) is still experimental and will be used over"
	ewarn "gui-libs/egl-wayland (v1) if both are installed, please remember"
	ewarn "to try uninstalling v2 if experience issues."
}



