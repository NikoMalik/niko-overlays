EAPI=8


EPYTHON=/usr/bin/python
PYTHON_COMPAT=( python3_{10..13} )

inherit git-r3

RESTRICT="network-sandbox sandbox userpriv"

DESCRIPTION="Welcome to a calmer internet "
HOMEPAGE="https://zen-browser.app"

EGIT_REPO_URI="https://github.com/zen-browser/desktop.git"

LICENSE="MPL-2.0"
SLOT="0"
KEYWORDS="~amd64 ~arm64"

DEPEND=""
RDEPEND=${DEPEND}

BDEPEND="dev-vcs/git
         net-misc/curl
         dev-lang/python
         dev-python/pip
         net-libs/nodejs[npm]
         dev-util/cbindgen
         dev-util/bindgen"

src_prepare() {
    npm i || die
    npm run init || die
    python ./scripts/update_en_US_packs.py || die
    npm run bootstrap || die
    eapply_user
}

src_compile() {
    npm run build --with-libclang-path="$(llvm-config --libdir)" || die
}
