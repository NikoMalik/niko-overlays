# Copyright 1999-2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit font

DESCRIPTION="A bitmap programming font optimized for coziness"
HOMEPAGE="https://github.com/slavfox/Cozette"
SRC_URI="https://github.com/slavfox/Cozette/releases/download/v.${PV}/CozetteFonts-v-${PV//./-}.zip"

S="${WORKDIR}/CozetteFonts"
LICENSE="MIT"
SLOT="0"
KEYWORDS="amd64 x86"

RESTRICT="mirror"

BDEPEND="app-arch/unzip"

FONT_SUFFIX="otb otf"

