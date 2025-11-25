EAPI=8

declare -g -r -A ZBS_DEPENDENCIES=(
	[ourio-0.0.0-_s-z0aEtAgC9FcfviiCNvmxZP2vvXsx3TMZsel5sgj6X.tar.gz]='https://github.com/NikoMalik/ourio/archive/02ed9e8d910c8e513e9344f3dab042fe06009dab.tar.gz'
	[zeit-0.6.0-5I6bk7V8AgAY0-hM-vUYtKZUFYhXct-VRkqISNNTfEfb.tar.gz]='https://github.com/rockorager/zeit/archive/ade14edb2025f5e4a57b683f81c915f70a904e88.tar.gz'
	[tls-0.1.0-ER2e0oNIBQDOLwOgkiNYg218M3CfQ8Y63KnacWSDolK3.tar.gz]='https://github.com/NikoMalik/tls.zig/archive/623a88ed2ac4a58045485e5dc97c95aafe829024.tar.gz'
	[zzdoc-0.0.0-tzT1Ph7cAAC5YmXQXiBJHAg41_A5AUAC5VOm7ShnUxlz.tar.gz]='https://github.com/rockorager/zzdoc/archive/a54223bdc13a80839ccf9f473edf3a171e777946.tar.gz'
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


src_configure() {
	local my_zbs_args=(
		-Dpie=true
		--release=fast
	)
	zig_src_configure
}


