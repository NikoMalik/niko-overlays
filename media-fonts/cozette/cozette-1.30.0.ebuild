# Copyright 1999-2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit font

DESCRIPTION="A bitmap programming font optimized for coziness"
HOMEPAGE="https://github.com/slavfox/Cozette"


SRC_URI="
	bitmap? (
		https://github.com/slavfox/${PN}/releases/download/v.${PV}/${PN}.otb -> ${P}.otb
		hidpi? ( https://github.com/slavfox/${PN}/releases/download/v.${PV}/${PN}_hidpi.otb -> ${P}_hidpi.otb )
	)
	vector? (
		https://github.com/slavfox/${PN}/releases/download/v.${PV}/${PN}Vector.otf -> ${PN}Vector-${PV}.otf
		https://github.com/slavfox/${PN}/releases/download/v.${PV}/${PN}VectorBold.otf -> ${PN}VectorBold-${PV}.otf
	)
"

S="${DISTDIR}"
FONT_S="${S}"
LICENSE="MIT"
SLOT="0"
KEYWORDS="amd64 x86"

RESTRICT="mirror"

IUSE="+fontconfig +bitmap +vector +hidpi"

BDEPEND="app-arch/unzip"

FONT_SUFFIX=""

src_prepare() {
	default

		
	if use bitmap; then
		FONT_SUFFIX+=" otb"
	fi
	if use vector; then
		FONT_SUFFIX+=" otf"
	fi

  if use fontconfig; then
		cat > "${T}/66-cozette.conf" <<-EOF
			<?xml version="1.0"?>
			<!DOCTYPE fontconfig SYSTEM "fonts.dtd">
			<fontconfig>

				<match target="pattern">
					<test name="family" qual="any">
						<string>Cozette</string>
					</test>
					<edit name="spacing" mode="assign">
						<int>100</int>
					</edit>
					<edit name="scalable" mode="assign">
						<bool>true</bool>
					</edit>
				</match>

				<match target="pattern">
					<test name="family" qual="any">
						<string>CozetteVector</string>
					</test>
					<edit name="spacing" mode="assign">
						<int>100</int>
					</edit>
					<edit name="scalable" mode="assign">
						<bool>true</bool>
					</edit>
				</match>





				<alias>
					<family>monospace</family>
					<prefer>
						<family>Cozette</family>
					</prefer>
				</alias>

				<alias>
					<family>Cozette</family>
					<default>
						<family>monospace</family>
					</default>
				</alias>


				<alias>
					<family>monospace</family>
					<prefer>
						<family>CozetteVector</family>
					</prefer>
				</alias>

				<alias>
					<family>CozetteVector</family>
					<default>
						<family>monospace</family>
					</default>
				</alias>



			</fontconfig>
		EOF

		assert "Failed to generate 66-cozette.conf"
		FONT_CONF=( "${T}/66-cozette.conf" )
	fi
}

