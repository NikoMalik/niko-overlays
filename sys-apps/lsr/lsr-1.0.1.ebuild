
EAPI=8



declare -g -r -A ZBS_DEPENDENCIES=(
	[ourio-091bb8893d03d002652631155eec5f429162be8d.tar.gz]='https://github.com/NikoMalik/ourio/archive/091bb8893d03d002652631155eec5f429162be8d.tar.gz'
	[zeit-ade14edb2025f5e4a57b683f81c915f70a904e88.tar.gz]='https://github.com/rockorager/zeit/archive/ade14edb2025f5e4a57b683f81c915f70a904e88.tar.gz'
	[zzdoc-a54223bdc13a80839ccf9f473edf3a171e777946.tar.gz]='https://github.com/rockorager/zzdoc/archive/a54223bdc13a80839ccf9f473edf3a171e777946.tar.gz'
)


ZIG_SLOT="0.15"
ZIG_NEEDS_LLVM=1

DESCRIPTION="ls but with io_uring "
HOMEPAGE="https://github.com/NikoMalik/lsr"


inherit verify-sig zig

SRC_URI="
	https://github.com/NikoMalik/${PN}/archive/refs/tags/v${PV}.tar.gz
	${ZBS_DEPENDENCIES_SRC_URI}
"

LICENSE="MIT"
SLOT="0"
KEYWORDS="amd64"



DOCS=( "README.md" )

src_unpack() {
	zig_src_unpack
}

src_configure() {
	local my_zbs_args=(
		-Dpie=true
		--release=fast
	)
	zig_src_configure
}

src_install() {
	zig_src_install
}
