EAPI=8


inherit cmake git-r3

DESCRIPTION="Hyprland graphics / resource utilities (git version)"
HOMEPAGE="https://github.com/hyprwm/hyprgraphics"
EGIT_REPO_URI="https://github.com/hyprwm/hyprgraphics.git"

LICENSE="BSD"
SLOT="0"
KEYWORDS=""

RDEPEND="
	>=gui-libs/hyprutils-0.1.1:=
	media-libs/libjpeg-turbo:=
	media-libs/libjxl:=
	media-libs/libspng
	media-libs/libwebp:=
	sys-apps/file
	x11-libs/cairo
"

DEPEND="${RDEPEND}"


