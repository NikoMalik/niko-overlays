EAPI=8


inherit meson-multilib git-r3

DESCRIPTION="NVIDIA Wayland EGL external platform library (git version)"
HOMEPAGE="https://github.com/NVIDIA/egl-wayland/"
EGIT_REPO_URI="https://github.com/NVIDIA/egl-wayland.git"

LICENSE="MIT"
SLOT="0"
KEYWORDS=""
IUSE=""

RDEPEND="
	dev-libs/wayland[${MULTILIB_USEDEP}]
	x11-libs/libdrm[${MULTILIB_USEDEP}]
"
DEPEND="
	${RDEPEND}
	>=dev-libs/wayland-protocols-1.34
	>=gui-libs/eglexternalplatform-1.1-r1
	media-libs/libglvnd
"
BDEPEND="
	dev-util/wayland-scanner
"

PATCHES=(
	"${FILESDIR}"/${PN}-1.1.6-remove-werror.patch
)

