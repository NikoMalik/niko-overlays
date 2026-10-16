# Copyright 2020-2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# shellcheck shell=bash
# shellcheck disable=SC2034,SC2155

EAPI=8

KERNEL_IUSE_GENERIC_UKI=1
KERNEL_IUSE_MODULES_SIGN=1

LLVM_COMPAT=( {17..22} )
LLVM_OPTIONAL=1

inherit eapi9-pipestatus toolchain-funcs flag-o-matic llvm-r2 kernel-build

# gentoo has no 7.2 patchset, reuse the 7.1 genpatches, they are generic and
# cachy_stage_patches only applies them up to the Gentoo KConfig patch
# https://distfiles.gentoo.org/pub/proj/dist-kernel/patchsets/
GENTOO_PATCHSET=linux-gentoo-patches-7.1.9
GENTOO_PATCHSET_DIR=7.1
# https://github.com/projg2/gentoo-kernel-config
GENTOO_CONFIG_VER=g19
# https://github.com/CachyOS/linux-cachyos
CONFIG_COMMIT=5a14cc870dbe958da0fe3fff96d0df6561b8b064
# https://github.com/CachyOS/kernel-patches
PATCH_COMMIT=17bb0bb818d283d0dc6e0280a2e9d5b95e66808b
# https://github.com/CachyOS/linux release revision, tarball is
# cachyos-<base>.<patch>-<CACHY_TAR_REL>.tar.gz and already carries the sauce
CACHY_TAR_REL=1
# bcachefs backports not wired for the minimal 7.2 port yet, empty disables it
# https://github.com/koverstreet/bcachefs-tools
# https://github.com/xarblu/bcachefs-patches
BCACHEFS_VER=

# minimal 7.2 port keeps only the bore flavour
FLAVOURS="bore"

# RCs only have main flavour
[[ "${PV}" == *_rc* ]] && FLAVOURS="cachyos"

# array of patches in format
# <use>:<path/to.patch>
# special use - always applies patch
# applied in this order
# CachyOS dropped the all/0001-cachyos-base-all.patch for 7.x, the 7.2 base is
# mainline + the bore scheduler patch + config tuning
CACHY_PATCH_SPECS=(
	# scheduler
	# bore:sched/0001-bore-cachy.patch
	# clang
	clang:misc/dkms-clang.patch
)

# bad patches that don't apply properly
# usually these are genpatches that are also included in the cachyos-base-all patch
# or genpatches that are not rebased yet (common for RCs)
BAD_PATCHES=()

DESCRIPTION="Linux kernel built with CachyOS and Gentoo patches"
HOMEPAGE="
	https://cachyos.org/
	https://github.com/CachyOS/linux-cachyos/
	https://www.kernel.org/
"

[[ "${PV}" != *_rc* ]] && KEYWORDS="~amd64"

# Gentoo patches and config
# the rest will be set via helpers below
SRC_URI="
	https://distfiles.gentoo.org/pub/proj/dist-kernel/patchsets/${GENTOO_PATCHSET_DIR}/${GENTOO_PATCHSET}.tar.xz
	https://github.com/projg2/gentoo-kernel-config/archive/${GENTOO_CONFIG_VER}.tar.gz
		-> gentoo-kernel-config-${GENTOO_CONFIG_VER}.tar.gz
"

IUSE="bcachefs cfi clang debug autofdo propeller mold +bbr +lto +polly ${FLAVOURS/cachyos/+cachyos}"
REQUIRED_USE="
	^^ ( ${FLAVOURS} )
	cfi? ( clang )
	lto? ( clang )
	polly? ( clang )
	clang? ( ${LLVM_REQUIRED_USE} )
	mold? ( !lto !cfi !autofdo !propeller )
"
RDEPEND="autofdo? ( dev-util/perf[libpfm] )"
# shellcheck disable=SC2016 # we don't want LLVM_SLOT to expand
BDEPEND="
	clang? ( $(llvm_gen_dep '
		llvm-core/clang:${LLVM_SLOT}=
		llvm-core/lld:${LLVM_SLOT}=
		llvm-core/llvm:${LLVM_SLOT}=
	') )
	debug? ( dev-util/pahole )
	mold? ( sys-devel/mold )
  app-arch/pigz	
"
PDEPEND="
	>=virtual/dist-kernel-${PV}
"

QA_FLAGS_IGNORED="
	usr/src/linux-.*/scripts/gcc-plugins/.*.so
	usr/src/linux-.*/vmlinux
	usr/src/linux-.*/arch/powerpc/kernel/vdso.*/vdso.*.so.dbg
"

if [[ "${PV}" == *_rc* ]]; then
	KERNEL_BASE_V="$(ver_cut 1).$(( $(ver_cut 2) - 1 ))"
else
	KERNEL_BASE_V="$(ver_cut 1-2)"
fi

# virtual RC conflicts with its stable equivalent
# because they have the same base
if [[ "${PV}" == *_rc0 ]]; then
	RDEPEND+=" !~${CATEGORY}/${PN}-${KERNEL_BASE_V}.0"
fi

CONFIG_P="${PN}-${KERNEL_BASE_V}-${CONFIG_COMMIT::8}"
PATCH_P="${PN}-${KERNEL_BASE_V}-${PATCH_COMMIT::8}"

# set the base source to the CachyOS prebuilt tarball and set S
# CachyOS 7.x ships a fork tarball with the sauce (CONFIG_CACHY etc) baked in,
# the scheduler patch applies on top of it, there is no kernel.org base or
# base-all patch anymore, so no incremental stable/rc patches either
kernel_base_env_setup() {
	local archive="cachyos-${KERNEL_BASE_V}.$(ver_cut 3)-${CACHY_TAR_REL}"
	declare -g SRC_URI="${SRC_URI}
		https://github.com/CachyOS/linux/releases/download/${archive}/${archive}.tar.gz
	"
	declare -g S="${WORKDIR}/${archive}"
	declare -g RC_PATCHES=()
	declare -g STABLE_PATCHES=()
}

# adds cachyos config sources to SRC_URI
cachy_config_env_setup() {
	local base spec cond patch file flavour
	local cachy_config_uris=""
	base="https://raw.githubusercontent.com/CachyOS/linux-cachyos"
	base+="/${CONFIG_COMMIT}"
	if [[ ${PV} == *_rc* ]]; then
		# RC only has cachyos flavour
		cachy_config_uris+="${base}/linux-cachyos-rc/config -> ${CONFIG_P}-cachyos.config "
	else
		for flavour in ${FLAVOURS}; do
			file="${CONFIG_P}-${flavour}.config"
			if [[ "${flavour}" == "cachyos" ]]; then
				cachy_config_uris+="${flavour}? ( ${base}/linux-cachyos/config -> ${file} ) "
			else
				cachy_config_uris+="${flavour}? ( ${base}/linux-cachyos-${flavour}/config -> ${file} ) "
			fi
		done
	fi
	declare -g SRC_URI="${SRC_URI} ${cachy_config_uris}"
}

# adds cachyos patch sources to SRC_URI
# and sets up IUSE_PATTERN to check if a flag is in IUSE
cachy_patch_env_setup() {
	local -a iuse_arr
	iuse_arr=( ${IUSE} )
	iuse_arr=( "${iuse_arr[@]#+}" )
	local IFS="|"
	declare -g IUSE_PATTERN="${iuse_arr[*]}"
	unset IFS

	local base spec cond patch file
	local cachy_patch_uris=""
	base="https://raw.githubusercontent.com/CachyOS/kernel-patches"
	base+="/${PATCH_COMMIT}/${KERNEL_BASE_V}"
	for spec in "${CACHY_PATCH_SPECS[@]}"; do
		cond="${spec%%:*}"
		patch="${spec#*:}"
		file="${PATCH_P}-${patch##*/}"
		if [[ "${cond}" == "-" ]]; then
			cachy_patch_uris+="${base}/${patch} -> ${file} "
		elif [[ "${cond}" =~ ${IUSE_PATTERN} ]]; then
			cachy_patch_uris+="${cond}? ( ${base}/${patch} -> ${file} ) "
		fi
	done
	declare -g SRC_URI="${SRC_URI} ${cachy_patch_uris}"
}

# adds bcachefs backport patch to SRC_URI
bcachefs_patch_env_setup() {
	[[ -z "${BCACHEFS_VER}" ]] && return

	declare -g BCACHEFS_PATCH="bcachefs-v${BCACHEFS_VER}-for-v${KERNEL_BASE_V}.patch"
	declare -g SRC_URI="${SRC_URI} bcachefs? (
		https://raw.githubusercontent.com/xarblu/bcachefs-patches/refs/heads/main/${KERNEL_BASE_V}/${BCACHEFS_PATCH}
	)"

	# enforce bcachefs-tools version on minor-level
	# to make sure there are no weird kernel/user-space
	# incompatibilities
	local bch_tools_min
	if [[ "${BCACHEFS_VER}" == *_pre* ]]; then
		bch_tools_min="$(ver_cut 1-2 "${BCACHEFS_VER}").0_pre0"
	else
		bch_tools_min="$(ver_cut 1-2 "${BCACHEFS_VER}").0"
	fi

	RDEPEND+="
		bcachefs? (
			>=sys-fs/bcachefs-tools-${bch_tools_min}
		)
	"
}

# env setup helpers
kernel_base_env_setup
cachy_config_env_setup
cachy_patch_env_setup
bcachefs_patch_env_setup

# get the selected flavour from FLAVOURS
cachy_flavour() {
	local flavour
	for flavour in ${FLAVOURS}; do
		if use "${flavour}"; then
			printf -- "%s" "${flavour}" || die
			return 0
		fi
	done
	die "Could not get selected flavour"
}

# get the "cachy name" of the kernel
# as in CachyOS/linux-cachyos repo
cachy_version() {
	case "$(cachy_flavour)" in
		cachyos)
			printf -- "-cachyos" || die
			;;
		*)
			printf -- "-cachyos-%s" "$(cachy_flavour)" || die
			;;
	esac
}

# get the config file name
cachy_base_config() {
	printf -- "%s-%s.config" "${CONFIG_P}" "$(cachy_flavour)" || die
}

# move required patches to ${WORKDIR}/patches
# and ensure they get applied in correct order
cachy_stage_patches() {
	local target="${WORKDIR}/patches"
	einfo "Staging patches to be applied in ${target} ..."
	mkdir -p "${target}" || die

	# RC patches are not compressed and thus in DISTDIR
	if [[ -n "${RC_PATCHES[*]}" ]]; then
		pushd "${DISTDIR}" >/dev/null || die
		cp -t "${target}" "${RC_PATCHES[@]}" || die
		popd >/dev/null || die
	fi

	# stable patches are compressed and thus in WORKDIR
	if [[ -n "${STABLE_PATCHES[*]}" ]]; then
		pushd "${WORKDIR}" >/dev/null || die
		cp -t "${target}" "${STABLE_PATCHES[@]}" || die
		popd >/dev/null || die
	fi

	# Gentoo patches live in ${WORKDIR}/${GENTOO_PATCHSET}
	pushd "${WORKDIR}/${GENTOO_PATCHSET}" >/dev/null || die
	local incr=2000
	local file
	for file in *.patch; do
		cp "${file}" "${target}/${incr}_${file#????-}" || die
		incr=$(( incr + 1 ))

		# we want everything up to the Gentoo KConfig patch
		# everything after it is considered experimental
		# according to gentoo-kernel ebuild
		if [[ "${file}" == *Add-Gentoo-Linux-support-config-settings* ]]; then
			break
		fi
	done
	popd >/dev/null || die

	# cachy patches need to be prefixed starting at 6000
	local incr=6000
	local spec cond patch file
	for spec in "${CACHY_PATCH_SPECS[@]}"; do
		IFS=":" read -r cond patch <<<"${spec}" || die
		file="${PATCH_P}-${patch##*/}"
		if [[ "${cond}" == "-" ]]; then
			true
		elif [[ "${cond}" =~ ${IUSE_PATTERN} ]] && use "${cond}"; then
			true
		else
			continue
		fi
		cp "${DISTDIR}/${file}" "${target}/${incr}_${file}" || die
		incr=$(( incr + 1 ))
	done

	# bcachefs backport patch is 6500
	if use bcachefs; then
		cp "${DISTDIR}/${BCACHEFS_PATCH}" \
			"${target}/6500_${BCACHEFS_PATCH}" || die
	fi

	# extra patches
	if [[ "$(cachy_flavour)" == deckify ]]; then
		# handheld.patch makes ath11k_pci use QCA206X firmware
		# this firmware A) is annoying to find and B) simply doesn't work
		cp -t "${target}" "${FILESDIR}/7000_revert-ath11k-firmware.patch" || die
	fi

	# remove problematic patches
	local patch
	for patch in "${BAD_PATCHES[@]}"; do
		rm "${target}/${patch}" || die
	done
}

# auto-detect closest march value
cachy_processor_opt() {
	# not supported but in case someone
	# builds on non amd64 return default
	if ! use amd64; then
		printf "GENERIC"
		return 0
	fi

	# apply X86_NATIVE_CPU if we have -march=native
	if [[ "$(get-flag march)" == native ]]; then
		printf "NATIVE"
		return 0
	fi

	# get closest march for others
	# mostly shameless rip from qt6-build.eclass
	# shellcheck disable=SC2086 # *FLAGS should split
	local march=$(
		$(tc-getCC) -E -P ${CFLAGS} ${CPPFLAGS} - <<-EOF | tail -n 1
			default
			#if (__CRC32__ + __LAHF_SAHF__ + __POPCNT__ + __SSE3__ + __SSE4_1__ + __SSE4_2__ + __SSSE3__) == 7
			x86-64-v2
			#  if (__AVX__ + __AVX2__ + __BMI__ + __BMI2__ + __F16C__ + __FMA__ + __LZCNT__ + __MOVBE__ + __XSAVE__) == 9
			x86-64-v3
			#    if (__AVX512BW__ + __AVX512CD__ + __AVX512DQ__ + __AVX512F__ + __AVX512VL__ + __EVEX256__ + __EVEX512__) == 7
			x86-64-v4
			#    endif
			#  endif
			#endif
		EOF
		pipestatus || die
	)
	case "${march}" in
		default) printf "GENERIC_V1";;
		x86-64-v2) printf "GENERIC_V2";;
		x86-64-v3) printf "GENERIC_V3";;
		x86-64-v4) printf "GENERIC_V4";;
		*) die "Got unknown march: ${march}";;
	esac
}

# print formatted kernel config line
# $1 can be one of set, unset, mod or val
# $2 config name as in CONFIG_<name>
# $3 if $1 is val set val as a config string
kconf() {
	if (( $# < 2 )); then
		die "kconf needs at least 2 args"
	fi
	case "$1" in
		set)
			printf -- "CONFIG_%s=y\n" "${2}" || die
			;;
		unset)
			printf -- "# CONFIG_%s is not set\n" "${2}" || die
			;;
		mod)
			printf -- "CONFIG_%s=m\n" "${2}" || die
			;;
		val)
			if [[ -z "${3}" ]]; then
				die "kconf val requires a value"
			fi
			printf -- "CONFIG_%s=%s\n" "${2}" "${3}" || die
			;;
		*)
			die "invalid option $1 for kconf"
			;;
	esac
}

# config defaults from CachyOS PKGBUILD
cachy_use_config() {
	# cachy config vars (only those that make sense in ebuild)
	# advanced users can override these with package.env
	case "$(cachy_flavour)" in
		bore)
			: "${_cachy_config:=yes}"
			: "${_cpusched:=bore}"
			: "${_cc_harder:=yes}"
			: "${_per_gov:=no}"
			: "${_tcp_bbr3:=yes}"
			: "${_HZ_ticks:=1000}"
			: "${_tickrate:=full}"
			: "${_preempt:=full}"
			: "${_hugepage:=always}"
			;;
		deckify)
			: "${_cachy_config:=yes}"
			: "${_cpusched:=cachyos}"
			: "${_cc_harder:=yes}"
			: "${_per_gov:=no}"
			: "${_tcp_bbr3:=yes}"
			: "${_HZ_ticks:=1000}"
			: "${_tickrate:=full}"
			: "${_preempt:=full}"
			: "${_hugepage:=always}"
			;;
		server)
			: "${_cachy_config:=no}"
			: "${_cpusched:=eevdf}"
			: "${_cc_harder:=yes}"
			: "${_per_gov:=no}"
			: "${_tcp_bbr3:=yes}"
			: "${_HZ_ticks:=300}"
			: "${_tickrate:=idle}"
			: "${_preempt:=none}"
			: "${_hugepage:=always}"
			;;
		rt-bore)
			: "${_cachy_config:=yes}"
			: "${_cpusched:=rt-bore}"
			: "${_cc_harder:=yes}"
			: "${_per_gov:=no}"
			: "${_tcp_bbr3:=yes}"
			: "${_HZ_ticks:=1000}"
			: "${_tickrate:=full}"
			: "${_preempt:=full}"
			: "${_hugepage:=always}"
			;;
		*) die "Unknown flavour" ;;
	esac

	: "${_processor_opt:="$(cachy_processor_opt)"}"

	if use cfi; then
		: "${_use_kcfi:=yes}"
	else
		: "${_use_kcfi:=no}"
	fi

	if use lto; then
		: "${_use_llvm_lto:=thin}"
	else
		: "${_use_llvm_lto:=none}"
	fi


	# print cachy config
	einfo "Selected cachy-config:"
	einfo "  _cachy_config=${_cachy_config}"
	einfo "  _cpusched=${_cpusched}"
	einfo "  _cc_harder=${_cc_harder}"
	einfo "  _per_gov=${_per_gov}"
	einfo "  _tcp_bbr3=${_tcp_bbr3}"
	einfo "  _HZ_ticks=${_HZ_ticks}"
	einfo "  _tickrate=${_tickrate}"
	einfo "  _preempt=${_preempt}"
	einfo "  _hugepage=${_hugepage}"
	einfo "  _processor_opt=${_processor_opt}"
	einfo "  _use_kcfi=${_use_kcfi}"
	einfo "  _use_llvm_lto=${_use_llvm_lto}"


	# _processor_opt
	local MARCH="${_processor_opt^^}"
	case "${MARCH}" in
		GENERIC) ;;
		GENERIC_V[1-4])
			kconf set GENERIC_CPU
			kconf unset MZEN4
			kconf unset X86_NATIVE_CPU
			kconf val X86_64_VERSION "${MARCH#GENERIC_V}"
			;;
		ZEN4)
			kconf unset GENERIC_CPU
			kconf set MZEN4
			kconf unset X86_NATIVE_CPU
			;;
		NATIVE)
			kconf unset GENERIC_CPU
			kconf unset MZEN4
			kconf set X86_NATIVE_CPU
			;;
		*) die "Invalid _processor_opt value: ${_processor_opt}" ;;
	esac

	# _cachy_config
	case "${_cachy_config}" in
		yes)
			kconf set CACHY
			;;
		no)	;;
		*) die "Invalid _cachy_config value: ${_cachy_config}" ;;
	esac

	# _cpusched
	case "${_cpusched}" in
		bore)
			kconf set SCHED_BORE
			;;
		rt-bore)
			kconf set SCHED_BORE
			kconf set PREEMPT_RT
			;;
		*) die "Invalid _cpusched value: ${_cpusched}" ;;
	esac

	# _use_kcfi
	case "${_use_kcfi}" in
		yes)
			kconf set ARCH_SUPPORTS_CFI_CLANG
			kconf set CFI_CLANG
			kconf set CFI_AUTO_DEFAULT
			;;
		no) ;;
		*) die "Invalid _use_kcfi value: ${_use_kcfi}" ;;
	esac

	# _use_llvm_lto
	case "${_use_llvm_lto}" in
		thin)
			kconf set LTO_CLANG_THIN
			;;
		full)
			kconf set LTO_CLANG_FULL
			;;
		none)
			kconf set LTO_NONE
			;;
		*) die "Invalid _use_llvm_lto value: ${_use_llvm_lto}" ;;
	esac

	# _HZ_ticks
	case "${_HZ_ticks}" in
		100|250|500|600|750|1000)
			kconf unset HZ_300
			kconf set "HZ_${_HZ_ticks}"
			kconf val HZ "${_HZ_ticks}"
			;;
		300)
			kconf set HZ_300
			kconf val HZ 300
			;;
		*) die "Invalid _HZ_ticks value: ${_HZ_ticks}" ;;
	esac

	# _per_gov
	case "${_per_gov}" in
		yes)
			kconf unset CPU_FREQ_DEFAULT_GOV_SCHEDUTIL
			kconf set CPU_FREQ_DEFAULT_GOV_PERFORMANCE
			;;
		no) ;;
		*) die "Invalid _per_gov value: ${_per_gov}" ;;
	esac

	# _tickrate
	case "${_tickrate}" in
		periodic)
			kconf unset NO_HZ_IDLE
			kconf unset NO_HZ_FULL
			kconf unset NO_HZ
			kconf unset NO_HZ_COMMON
			kconf set HZ_PERIODIC
			;;
		idle)
			kconf unset HZ_PERIODIC
			kconf unset NO_HZ_FULL
			kconf set NO_HZ_IDLE
			kconf set NO_HZ
			kconf set NO_HZ_COMMON
			;;
		full)
			kconf unset HZ_PERIODIC
			kconf unset NO_HZ_IDLE
			kconf unset CONTEXT_TRACKING_FORCE
			kconf set NO_HZ_FULL_NODEF
			kconf set NO_HZ_FULL
			kconf set NO_HZ
			kconf set NO_HZ_COMMON
			kconf set CONTEXT_TRACKING
			;;
		*) die "Invalid _tickrate value: ${_tickrate}" ;;
	esac

	# _preempt
	if [[ "${_cpusched}" != rt* ]]; then
		case "${_preempt}" in
			full)
				kconf set PREEMPT_DYNAMIC
				kconf set PREEMPT
				kconf unset PREEMPT_VOLUNTARY
				kconf unset PREEMPT_LAZY
				kconf unset PREEMPT_NONE
				;;
			lazy)
				kconf set PREEMPT_DYNAMIC
				kconf unset PREEMPT
				kconf unset PREEMPT_VOLUNTARY
				kconf set PREEMPT_LAZY
				kconf unset PREEMPT_NONE
				;;
			voluntary)
				kconf unset PREEMPT_DYNAMIC
				kconf unset PREEMPT
				kconf set PREEMPT_VOLUNTARY
				kconf unset PREEMPT_LAZY
				kconf unset PREEMPT_NONE
				;;
			none)
				kconf unset PREEMPT_DYNAMIC
				kconf unset PREEMPT
				kconf unset PREEMPT_VOLUNTARY
				kconf unset PREEMPT_LAZY
				kconf set PREEMPT_NONE
				;;
			*) die "Invalid _preempt value: ${_preempt}" ;;
		esac
	fi

	# _cc_harder
	case "${_cc_harder}" in
		yes)
			kconf unset CC_OPTIMIZE_FOR_PERFORMANCE
			kconf set CC_OPTIMIZE_FOR_PERFORMANCE_O3
			;;
		no) ;;
		*) die "Invalid _cc_harder value: ${_cc_harder}" ;;
	esac

	# _tcp_bbr3
	case "${_tcp_bbr3}" in
		yes)
			kconf mod TCP_CONG_CUBIC
			kconf unset DEFAULT_CUBIC
			kconf set TCP_CONG_BBR
			kconf val DEFAULT_TCP_CONG "\"bbr\""
			kconf mod NET_SCH_FQ_CODEL
			kconf set NET_SCH_FQ
			kconf unset CONFIG_DEFAULT_FQ_CODEL
			kconf set CONFIG_DEFAULT_FQ
			;;
		no)	;;
		*) die "Invalid _tcp_bbr3 value: ${_tcp_bbr3}" ;;
	esac

	# _hugepage
	case "${_hugepage}" in
		always)
			kconf unset TRANSPARENT_HUGEPAGE_MADVISE
			kconf set TRANSPARENT_HUGEPAGE_ALWAYS
			;;
		madvise)
			kconf unset TRANSPARENT_HUGEPAGE_ALWAYS
			kconf set TRANSPARENT_HUGEPAGE_MADVISE
			;;
		*) die "Invalid _hugepage value: ${_hugepage}" ;;
	esac

	# _user_ns
	kconf set USER_NS

	# handheld only
	if [[ "$(cachy_flavour)" == deckify ]]; then
		kconf unset RCU_LAZY_DEFAULT_OFF
		kconf set AMD_PRIVATE_COLOR
	fi

	# bcachefs defaults
	if use bcachefs; then
		kconf mod BCACHEFS_FS
		kconf set BCACHEFS_QUOTA
		kconf set BCACHEFS_POSIX_ACL
		kconf set BCACHEFS_LOCK_TIME_STATS
		kconf set BCACHEFS_SIX_OPTIMISTIC_SPIN
	fi



    # possible issues on nvidia and amd
	# kconf unset INIT_ON_ALLOC_DEFAULT_ON
	# einfo "Unset INIT_ON_ALLOC_DEFAULT_ON"

  kconf set EXPERT
	kconf set SCHED_CLUSTER
	einfo "SCHED_CLUSTER ENABLED"

	kconf set SCHED_SMT
	einfo "SCHED_SMT ENABLED"

	kconf set LRU_GEN_ENABLED
	kconf set LRU_GEN
	einfo "LRU_GEN_ENABLED enabled"

	kconf set NET_RX_BUSY_POLL
	kconf set BUSY_POLL

	kconf unset DEBUG_MEMORY_INIT

    kconf unset SHRINKER_DEBUG
	kconf unset BLK_DEBUG_FS
    kconf unset MODULE_DEBUGFS
    kconf unset CMA_DEBUGFS
    kconf unset NVME_TARGET_DEBUGFS
    kconf unset VFIO_DEBUGFS
	kconf unset ATH5K_DEBUG
    kconf unset ATH9K_COMMON_DEBUG
    kconf unset ATH9K_DEBUGFS
    kconf unset ATH10K_DEBUG
    kconf unset ATH10K_DEBUGFS
    kconf unset ATH11K_DEBUG
    kconf unset ATH11K_DEBUGFS
    kconf unset ATH12K_DEBUG
    kconf unset ATH12K_DEBUGFS
    kconf unset IWLWIFI_DEBUG
    kconf unset IWLWIFI_DEBUGFS
    kconf unset RTW88_DEBUG
    kconf unset RTW89_DEBUG
    kconf unset RTW89_DEBUGMSG
	kconf unset NETFS_DEBUG
    kconf unset NFS_DEBUG
    kconf unset SUNRPC_DEBUG
    kconf unset CIFS_DEBUG
    kconf unset DLM_DEBUG
	kconf unset VIRTIO_DEBUG
    kconf unset DM_DEBUG
    kconf unset DM_DEBUG_BLOCK_MANAGER_LOCKING
    kconf unset MLX4_DEBUG
    kconf unset DYNAMIC_DEBUG_CORE
    kconf unset DEBUG_BUGVERBOSE
	kconf unset SECURITY_DMESG_RESTRICT
	kconf unset SECURITY_PERF_EVENTS_RESTRICT
	kconf unset STACKTRACE
    kconf unset STACKTRACE_BUILD_ID
    kconf unset USER_STACKTRACE_SUPPORT
    kconf unset SCSI_IPR_TRACE
    kconf unset TRACE_GPU_MEM
    einfo "Disabled tracing debug"


	kconf unset SLAB_FREELIST_RANDOM
	kconf unset SLAB_FREELIST_HARDEN
	einfo "SLAB_RANDOM DISABLED"

	kconf unset SHUFFLE_PAGE_ALLOCATOR
	kconf set PER_VMA_LOCK

	kconf unset KFENCE
	kconf unset DEBUG_WX
	kconf unset DEBUG_MEMORY_INIT
	kconf unset SCHEDSTATS
    # kconf unset FTRACE  # needed for BPF_EVENTS
    kconf unset FUNCTION_TRACER
		kconf unset FTRACE
    kconf unset STACK_TRACER
    kconf unset SCHED_TRACER
    # kconf unset KPROBES  # needed for BPF_EVENTS
    kconf unset PROFILING
		kconf unset KPROBES
    kconf unset NUMA_BALANCING
    kconf unset ACPI_DEBUG
    kconf unset PM_DEBUG
    kconf unset PM_SLEEP_DEBUG
    kconf unset DYNAMIC_DEBUG
    kconf unset PAGE_POISONING
	kconf unset DEBUG_FS
	kconf unset SLUB_DEBUG
	kconf unset DEBUG_MEMORY
	kconf unset SND_DEBUG
  kconf unset SLUB_DEBUG
  kconf unset MITIGATION_SL
  kconf unset DRM_NOUVEAU
	# BPF_EVENTS will be enabled automatically when FTRACE and KPROBES are enabled





	if use autofdo; then
		kconf set AUTOFDO_CLANG
		einfo "CONFIG_AUTO_FDO enabled"
	fi

	if use propeller; then
		kconf set PROPELLER_CLANG
		einfo "CONFIG_PROPELLER_CLANG enabled"
	fi

	if use polly; then
		kconf set POLLY_CLANG
	fi




}

pkg_pretend() {
	# die instead of just masking/dropping USE
	# to make extra sure users don't unknowingly lose
	# access to their filesystem
	if use bcachefs && [[ -z "${BCACHEFS_VER}" ]]; then
		eerror "bcachefs is currently broken on kernel $(ver_cut 1-2)"
		eerror "Failing early to make sure you know and don't lose access to your fs"
		die "broken bcachefs"
	fi

	if use bcachefs; then
		elog "This kernel will have support for bcachefs ${BCACHEFS_VER} built in"
	fi

	kernel-install_pkg_pretend
}

pkg_setup() {
	if [[ "${MERGE_TYPE}" != binary ]] && use clang; then
		# tools passed as MAKEARGS in kernel-build.eclass
		einfo "Forcing LLVM toolchain due to USE=clang"
		declare -g AS="llvm-as"
		declare -g CC="clang"
		declare -g LD="ld.lld"
		declare -g AR="llvm-ar"
		declare -g NM="llvm-nm"
		declare -g STRIP="llvm-strip"
		declare -g OBJCOPY="llvm-objcopy"
		declare -g OBJDUMP="llvm-objdump"
		declare -g READELF="llvm-readelf"
		# explicit prepend_path to ensure vars point to correct version
		llvm_prepend_path -b "${LLVM_SLOT}"
		llvm-r2_pkg_setup
		einfo "AS: ${AS}"
		einfo "CC: ${CC}"
		einfo "LD: ${LD}"
		einfo "AR: ${AR}"
		einfo "NM: ${NM}"
		einfo "STRIP: ${STRIP}"
		einfo "OBJCOPY: ${OBJCOPY}"
		einfo "OBJDUMP: ${OBJDUMP}"
		einfo "READELF: ${READELF}"
	fi
	if [[ "${MERGE_TYPE}" != binary ]] && use mold; then
		# mold only fits the non-LTO link, LTO bitcode needs lld built-in LTO,
		# the kernel calls LD directly so mold never gets the LLVMgold.so plugin
		einfo "Using mold as kernel linker (LD=ld.mold)"
		declare -g LD="ld.mold"
		einfo "LD: ${LD}"
	fi
	kernel-build_pkg_setup
}

src_prepare() {
	# prepare and stage patches
	cachy_stage_patches

	# apply package and user patches
	eapply "${WORKDIR}/patches"
	einfo "Applying local patches"

	# teach ld-version.sh about mold so LD=ld.mold is not rejected, non-LTO only
	use mold && eapply "${FILESDIR}/6.18.1-mold-ld-version.patch"

  if use bore; then
		eapply "${FILESDIR}/7.2.10-bore.patch"
	fi
  eapply "${FILESDIR}/6.18.1-spin-faster.patch"
  eapply "${FILESDIR}/6.18.1-harder-flags.patch"
  eapply "${FILESDIR}/6.18.1-nvme-latency.patch"
 	eapply "${FILESDIR}/6.18.1-mm-branch.patch"
  eapply "${FILESDIR}/7.2.10-kcompressed.patch"
  eapply "${FILESDIR}/6.18.1-polly.patch"
  eapply "${FILESDIR}/6.18.1-reduce-dcache.patch"
  eapply "${FILESDIR}/6.18.1-bitmap-syscall-audit.patch"
  eapply "${FILESDIR}/6.18.1-sk-packets-sock.patch"
  eapply "${FILESDIR}/6.18.1-scale-net-alloc.patch"
  eapply "${FILESDIR}/6.18.1-align-dst.patch"
  eapply "${FILESDIR}/6.18.1-align-slab.patch"
  eapply "${FILESDIR}/6.18.1-ext4.patch"
  eapply "${FILESDIR}/6.18.1-elf-optimize.patch"
  eapply "${FILESDIR}/7.2.10-mem_page.patch" 
  eapply "${FILESDIR}/6.18.1-sched-limit.patch"
  # poc selector already there
  eapply "${FILESDIR}/6.18.1-rq-affinity.patch"
	eapply "${FILESDIR}/6.18.1-sbitmap-bits.patch"
	eapply "${FILESDIR}/7.2.10-zstd.patch"
	eapply "${FILESDIR}/7.2.10-rss-stat-optimization.patch"
	eapply "${FILESDIR}/7.2.10-reflex.patch"
	eapply "${FILESDIR}/6.18.1-disable-workqueue-crypto.patch"
	eapply "${FILESDIR}/7.2.10-min-write-back.patch"
  eapply "${FILESDIR}/6.18.1-nap.patch"
  eapply "${FILESDIR}/6.18.1-reuse-timer.patch"
	eapply "${FILESDIR}/6.18.1-hashtable-conn.patch"
  eapply "${FILESDIR}/6.18.1-intsqrt.patch"
  eapply "${FILESDIR}/6.18.1-map_count.patch"
  eapply "${FILESDIR}/6.18.1-unwait.patch"
  eapply "${FILESDIR}/6.18.1-small_buf_file.patch"
  eapply "${FILESDIR}/7.2.10-speedup_entry.patch"
  eapply "${FILESDIR}/6.18.1-limit-cpu.patch"
  eapply "${FILESDIR}/6.18.1-pci.patch"
  eapply "${FILESDIR}/7.2.10-cpuidle-nvme.patch"
  eapply "${FILESDIR}/6.18.1-dma-buf.patch"
  eapply "${FILESDIR}/6.18.1-pctl-stack.patch"
  eapply "${FILESDIR}/6.18.1-numa-present.patch"
  eapply "${FILESDIR}/6.18.1-list-lock.patch"
  eapply "${FILESDIR}/6.18.1-file-8.patch"
  eapply "${FILESDIR}/7.2.10-comptime_ttwu.patch"
  eapply "${FILESDIR}/6.18.1-epb.patch"
  eapply "${FILESDIR}/6.18.1-crypto-late.patch"
  eapply "${FILESDIR}/6.18.1-memcontrol.patch"
  eapply "${FILESDIR}/6.18.1-better_idle.patch"
  # ThinLTO drop the calc_concur_shares static-call target -> undefined at link
  eapply "${FILESDIR}/6.18.1-lto-size.patch"
  eapply "${FILESDIR}/6.18.1-harder_clang.patch"
  eapply "${FILESDIR}/6.18.1-mharden_none.patch"
  eapply "${FILESDIR}/6.18.1-fix_busy_amd.patch"
  eapply "${FILESDIR}/6.18.1-epp_retune.patch"
  eapply "${FILESDIR}/6.18.1-ttm.patch"
  eapply "${FILESDIR}/6.18.1-vfs_speedup.patch"
  eapply "${FILESDIR}/6.18.1-clear_page_no_gpl.patch"
  # eapply "${FILESDIR}/6.18.1-btf_binary.patch"
  eapply "${FILESDIR}/6.18.1-dead_code.patch"
  eapply "${FILESDIR}/7.2.10-net_filter.patch"
  eapply "${FILESDIR}/7.2.10-write_buffer.patch"
  eapply "${FILESDIR}/7.2.10-mput_async.patch"
  eapply "${FILESDIR}/7.2.10-filemap_retry.patch"
  # cgroup_vram dropped - dmem cgroup min/low + TTM VRAM integration is native in 7.2
  eapply "${FILESDIR}/7.2.10-tcp_collapse.patch"
  eapply "${FILESDIR}/7.2.10-block_patches.patch"
  # eapply "${FILESDIR}/7.2.10-drm-gud.patch"
  eapply "${FILESDIR}/7.2.10-lib-group.patch"
  # keep the calc_*_shares static-call targets under ThinLTO (undefined
  # calc_concur_shares at vmlinux link otherwise), applied last so its context
  # (the bare "static long calc_*_shares" lines) stays stable
  eapply "${FILESDIR}/7.2.10-sched-shares-lto-fix.patch"
  eapply "${FILESDIR}/7.2.10-def_string.patch"
  eapply "${FILESDIR}/7.2.10-speedup_compile.patch"
  eapply "${FILESDIR}/7.2.10-pci_skip.patch"
  eapply "${FILESDIR}/7.2.10-fast_parse_uint.patch"































	eapply_user

	# Localversion
	kconf val LOCALVERSION "\"$(cachy_version)\"" > "${T}/version.config" || die

	# CachyOS config as base
	cp "${DISTDIR}/$(cachy_base_config)" .config || die

	# Package defaults
	cachy_use_config > "${T}/cachy-flavour-defaults.config" || die

	# Gentoo defaults
	local dist_conf_path="${WORKDIR}/gentoo-kernel-config-${GENTOO_CONFIG_VER}"

	local merge_configs=(
		"${T}/version.config"
		"${dist_conf_path}/base.config"
		"${dist_conf_path}/6.12+.config"
		"${T}/cachy-flavour-defaults.config"
	)


	use debug || merge_configs+=(
		"${dist_conf_path}/no-debug.config"
	)

	use secureboot && merge_configs+=(
		"${dist_conf_path}/secureboot.config"
		"${dist_conf_path}/zboot.config"
	)

	kernel-build_merge_configs "${merge_configs[@]}"
}

src_configure() {
	# spoof PV for virtual RC to make the
	# "version mismatch check" happy
	if [[ "${PV}" == *_rc0 ]]; then
		local PV="${KERNEL_BASE_V}"
	fi
	kernel-build_src_configure
}

pkg_preinst() {
	# spoof PV for virtual RC to make the
	# "version mismatch check" happy
	if [[ "${PV}" == *_rc0 ]]; then
		local PV="${KERNEL_BASE_V}"
	fi
	kernel-install_pkg_preinst
}

pkg_postinst() {
	kernel-build_pkg_postinst

	# print info for included modules
	if use bcachefs && has_version sys-fs/bcachefs-kmod; then
		elog "bcachefs ${BCACHEFS_VER} is included in ${CATEGORY}/${PN} - no need for sys-fs/bcachefs-kmod"
	fi

	if has_version media-video/v4l2loopback; then
		elog "v4l2loopback is included in ${CATEGORY}/${PN} - no need for media-video/v4l2loopback"
	fi

	(use autofdo || use propeller) && ewarn "AutoFDO support build way: https://cachyos.org/blog/2411-kernel-autofdo, and you can check https://github.com/xz-dev/kernel-autofdo-container as example"
}
