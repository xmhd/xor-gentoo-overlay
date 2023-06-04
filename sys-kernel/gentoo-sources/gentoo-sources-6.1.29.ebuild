# Distributed under the terms of the GNU General Public License v2

EAPI=7

inherit toolchain-funcs

DESCRIPTION="Linux kernel sources with some additional patches."
HOMEPAGE="https://kernel.org"

LICENSE="GPL-2"
KEYWORDS="~amd64"

SLOT="${PV%%_p*}"

RESTRICT="binchecks mirror strip"

# general kernel USE flags
IUSE="build-kernel clang compress debug minimal +symlink"
# security
IUSE="${IUSE} cpu-mitigations hardened +kpti +retpoline selinux sign-modules"
# initramfs
IUSE="${IUSE} btrfs +firmware luks lvm mdadm microcode plymouth udev zfs"
# misc kconfig tweaks
IUSE="${IUSE} +mcelog +memcg +numa"

BDEPEND="
	sys-devel/bc
	debug? ( dev-util/pahole )
	sys-devel/flex
	virtual/libelf
	app-alternatives/yacc
"

RDEPEND="
	build-kernel? ( sys-kernel/genkernel )
	btrfs? ( sys-fs/btrfs-progs )
	compress? ( sys-apps/kmod[lzma] )
	firmware? (
		sys-kernel/linux-firmware
	)
	luks? ( sys-fs/cryptsetup )
	lvm? ( sys-fs/lvm2 )
	mdadm? ( sys-fs/mdadm )
	mcelog? ( app-admin/mcelog )
	plymouth? (
		x11-libs/libdrm[libkms]
		sys-boot/plymouth[libkms,udev]
	)
	sign-modules? (
		dev-libs/openssl
		sys-apps/kmod
	)
	zfs? ( sys-fs/zfs )
"

REQUIRED_USE="
	sign-modules? ( build-kernel )
"


KERNEL_VERSION="${PV%%_*}"
KERNEL_EXTRAVERSION="-gentoo"
KERNEL_FULL_VERSION="${KERNEL_VERSION}${KERNEL_EXTRAVERSION}"

KERNEL_ARCHIVE="linux-${KERNEL_VERSION}.tar.xz"
KERNEL_UPSTREAM="https://cdn.kernel.org/pub/linux/kernel/v6.x/${KERNEL_ARCHIVE}"

KERNEL_CONFIG="TODO"
KERNEL_CONFIG_UPSTREAM="https://git.alpinelinux.org/aports/plain/main/linux-lts/"

SRC_URI="
	${KERNEL_UPSTREAM}

	x86? (
		minimal? ( ${KERNEL_CONFIG_UPSTREAM}/virt.x86.config -> alpine-kconfig-virt-x86-${PV} )
		!minimal? ( ${KERNEL_CONFIG_UPSTREAM}/lts.x86.config -> alpine-kconfig-x86-${PV} )
	)
	amd64? (
		minimal? ( ${KERNEL_CONFIG_UPSTREAM}/virt.x86_64.config -> alpine-kconfig-virt-amd64-${PV} )
		!minimal? ( ${KERNEL_CONFIG_UPSTREAM}/lts.x86_64.config -> alpine-kconfig-amd64-${PV} )
	)
	arm? (
		minimal? ( ${KERNEL_CONFIG_UPSTREAM}/virt.armv7.config -> alpine-kconfig-virt-arm-${PV} )
		!minimal? ( ${KERNEL_CONFIG_UPSTREAM}/lts.armv7.config -> alpine-kconfig-arm-${PV} )
	)
	arm64? (
		minimal? ( ${KERNEL_CONFIG_UPSTREAM}/virt.aarch64.config -> alpine-kconfig-virt-arm64-${PV} )
		!minimal? ( ${KERNEL_CONFIG_UPSTREAM}/lts.aarch64.config -> alpine-kconfig-arm64-${PV} )
	)
"

S="$WORKDIR/linux-${KERNEL_VERSION}"

GENTOO_PATCHES_DIR="${FILESDIR}/${KERNEL_VERSION}/gentoo-patches"
GENTOO_PATCHES=(
	1500_XATTR_USER_PREFIX.patch
	1510_fs-enable-link-security-restrictions-by-default.patch
	1700_sparc-address-warray-bound-warnings.patch
	2000_BT-Check-key-sizes-only-if-Secure-Simple-Pairing-enabled.patch
	2100_io-uring-undeprecate-epoll-ctl-support.patch
	2900_tmp513-Fix-build-issue-by-selecting-CONFIG_REG.patch
	2910_bfp-mark-get-entry-ip-as--maybe-unused.patch
	2920_sign-file-patch-for-libressl.patch
	2930_gcc-plugins-Reorg-gimple-incs-for-gcc-13.patch
	3000_Support-printing-firmware-info.patch
	4567_distro-Gentoo-Kconfig.patch
	5000_shiftfs-6.1.patch
	5010_enable-cpu-optimizations-universal.patch
	5020_BMQ-and-PDS-io-scheduler-v6.1-r4-linux-tkg.patch
	5021_BMQ-and-PDS-gentoo-defaults.patch
	5022_BMQ-and-PDS-remove-psi-support.patch
)

tweak_config() {
	echo "$1" >> .config || die "failed to tweak \"$1\" in the kernel config"
}

get_certs_dir() {
	# find a certificate dir in /etc/kernel/certs/ that contains signing cert for modules.
	for subdir in ${PF} ${P} linux; do
		certdir=/etc/kernel/certs/${subdir}
		if [[ -d ${certdir} ]]; then
			if [[ ! -e ${certdir}/signing_key.pem ]]; then
				die  "${certdir} exists but missing signing key; exiting."
				exit 1
			fi
			echo ${certdir}
			return
		fi
	done
}

pkg_pretend() {

	# a lot of hardware requires firmware
	if ! use firmware; then
		ewarn "sys-kernel/linux-firmware not found installed on your system."
		ewarn "This package provides firmware that may be needed for your hardware to work."
	fi
}

pkg_setup() {

	# will interfere with Makefile if set
	unset ARCH
	unset LDFLAGS
}

src_unpack() {

	# unpack the kernel sources to ${WORKDIR}
	unpack ${KERNEL_ARCHIVE}
}

src_prepare() {

# PATCH:

	# apply gentoo patches
	einfo "Applying Gentoo Linux patches ..."
	for my_patch in ${GENTOO_PATCHES[*]}; do
		eapply "${GENTOO_PATCHES_DIR}/${my_patch}"
	done

	# TODO
	eapply "${FILESDIR}/${KERNEL_VERSION}/config-default-cpu-mitigations-off.patch"

	# Restore the original Linux default of allowing devices to negotiate their own connection interval
	eapply "${FILESDIR}/${KERNEL_VERSION}/fix-bluetooth-polling.patch"

	# apply any user patches
	eapply_user

	# append EXTRAVERSION to the kernel sources Makefile
	sed -i -e "s:^\(EXTRAVERSION =\).*:\1 ${KERNEL_EXTRAVERSION}:" Makefile || die "failed to append EXTRAVERSION to kernel Makefile"

	# todo: look at this, haven't seen it used in many cases.
	sed -i -e 's:#export\tINSTALL_PATH:export\tINSTALL_PATH:' Makefile || die "failed to fix-up INSTALL_PATH in kernel Makefile"


	# copy the kconfig file into the kernel sources tree
	cp "${DISTDIR}"/alpine-kconfig-* "${S}"/.config || die "failed to install .config to kernel source tree"

# CONFIG:

	# TODO
	tweak_config "CONFIG_GENTOO_LINUX=y"

	# Do not configure Debian trusted certificates
	tweak_config 'CONFIG_SYSTEM_TRUSTED_KEYS=""'

	# enable IKCONFIG so that /proc/config.gz can be used for various checks
	# TODO: Maybe not a good idea for USE=hardened, look into this...
	tweak_config "CONFIG_IKCONFIG=y"
	tweak_config "CONFIG_IKCONFIG_PROC=y"

	# enable kernel module compression ...
	# ... defaulting to xz compression
	if use compress; then
		tweak_config "CONFIG_MODULE_COMPRESS_NONE=n"
		tweak_config "CONFIG_MODULE_COMPRESS_GZIP=n"
		tweak_config "CONFIG_MODULE_COMPRESS_ZSTD=n"
		tweak_config "CONFIG_MODULE_COMPRESS_XZ=y"
	else
		tweak_config "CONFIG_MODULE_COMPRESS_NONE=y"
	fi

	if use cpu-mitigations; then
		tweak_config "CONFIG_DEFAULT_CPU_MITIGATIONS_OFF=n"
	else
		tweak_config "CONFIG_DEFAULT_CPU_MITIGATIONS_OFF=y"
	fi

	# only enable debugging symbols etc if USE=debug...
	if use debug; then
		tweak_config "CONFIG_DEBUG_INFO=y"
		tweak_config "CONFIG_DEBUG_INFO_BTF=y"
	else
		tweak_config "CONFIG_DEBUG_INFO=n"
		tweak_config "CONFIG_DEBUG_INFO_BTF=n"
	fi

	if use hardened; then

		# TODO: HARDENING

		tweak_config "CONFIG_GENTOO_KERNEL_SELF_PROTECTION=y"

		# disable gcc plugins on clang
		if use clang; then
			tweak_config "CONFIG_GCC_PLUGINS=n"
		fi

		# main hardening options complete... anything after this point is a focus on disabling potential attack vectors
		# i.e legacy drivers, new complex code that isn't yet proven, or code that we really don't want in a hardened kernel.

		# Kexec is a syscall that enables loading/booting into a new kernel from the currently running kernel.
		# This has been used in numerous exploits of various systems over the years, so we disable it.
		# TODO: USE flag this?
		tweak_config 'CONFIG_KEXEC=n'
		tweak_config "CONFIG_KEXEC_FILE=n"
		tweak_config 'CONFIG_KEXEC_SIG=n'
	fi

	# mcelog is deprecated, but there are still some valid use cases and requirements for it... so stick it behind a USE flag for optional kernel support.
	if use mcelog; then
		tweak_config "CONFIG_X86_MCELOG_LEGACY=y"
	fi

	if use memcg; then
		tweak_config "CONFIG_MEMCG=y"
	else
		tweak_config "CONFIG_MEMCG=n"
	fi

	if use numa; then
		tweak_config "CONFIG_NUMA_BALANCING=y"
	else
		tweak_config "CONFIG_NUMA_BALANCING=n"
	fi

	# sign kernel modules via
	if use sign-modules; then
		certs_dir=$(get_certs_dir)
		if [[ -z "${certs_dir}" ]]; then
			die "No certs dir found in /etc/kernel/certs; aborting."
		else
			einfo "Using certificate directory of ${certs_dir} for kernel module signing."
		fi
		# turn on options for signing modules.
		# first, remove existing configs and comments:
		tweak_config 'CONFIG_MODULE_SIG=""'

		# now add our settings:
		tweak_config 'CONFIG_MODULE_SIG=y'
		tweak_config 'CONFIG_MODULE_SIG_FORCE=n'
		tweak_config 'CONFIG_MODULE_SIG_ALL=n'
		tweak_config 'CONFIG_MODULE_SIG_HASH="sha512"'
		tweak_config 'CONFIG_MODULE_SIG_KEY="${certs_dir}/signing_key.pem"'
		tweak_config 'CONFIG_SYSTEM_TRUSTED_KEYRING=y'
		tweak_config 'CONFIG_SYSTEM_EXTRA_CERTIFICATE=y'
		tweak_config 'CONFIG_SYSTEM_EXTRA_CERTIFICATE_SIZE="4096"'
		tweak_config "CONFIG_MODULE_SIG_SHA512=y"
	fi

	# get config into good state:
	yes "" | make oldconfig >/dev/null 2>&1 || die
	cp .config "${T}"/.config || die
	make -s mrproper || die "make mrproper failed"
}

src_compile() {

	export SANDBOX_ON=0

	if use build-kernel; then

		# TODO: genkernel dirs
		install -d "${WORKDIR}"/genkernel/{cache,temp,log}

		# TODO: build dir
		install -d "${WORKDIR}"/build

		# TODO: install files dir
		install -d "${WORKDIR}"/out/{boot,lib}

		# TODO
		cp "${T}"/.config "${WORKDIR}"/build/.config

		GKARGS=(
			--color
			--makeopts="${MAKEOPTS}"
			--logfile="${WORKDIR}"/genkernel/log/genkernel.log
			--cachedir="${WORKDIR}"/genkernel/cache
			--tmpdir="${WORKDIR}"/genkernel/temp
			$(usex debug --loglevel=5 --loglevel=1)

			--no-save-config
			--no-oldconfig
			--no-menuconfig
			--no-module-rebuild
			--kernel-config="${T}/.config"
			--kerneldir="${S}"
			--kernel-outputdir="${WORKDIR}"/build
			--kernel-modules-prefix="${WORKDIR}"/out
			--bootdir="${WORKDIR}"/out/boot

			--all-ramdisk-modules
			--compress-initramfs
			--compress-initramfs-type=xz
			$(usex btrfs --btrfs --no-btrfs)
			$(usex firmware --firmware --no-firmware)
			$(usex lvm --lvm --no-lvm)
			$(usex mdadm --mdadm --no-mdadm)
			$(usex microcode --microcode-initramfs --no-microcode-initramfs)
			$(usex zfs --zfs --no-zfs)
		)

		genkernel ${GKARGS[@]} all || die
	fi
}

# this can likely be done a bit better
# TODO: create backups of kernel + initramfs if same ver exists?
install_kernel_and_friends() {

	install -d "${D}"/boot
	local kern_arch=$(tc-arch-kernel)

	cp "${WORKDIR}"/build/arch/${kern_arch}/boot/bzImage "${D}"/boot/vmlinuz-${KERNEL_FULL_VERSION} || die "failed to install kernel to /boot"
	cp "${T}"/.config "${D}"/boot/config-${KERNEL_FULL_VERSION} || die "failed to install kernel config to /boot"
	cp "${WORKDIR}"/build/System.map "${D}"/boot/System.map-${KERNEL_FULL_VERSION} || die "failed to install System.map to /boot"
}

src_install() {

	# 'standard' install of kernel sources that most consumers are used to ...
	# i.e. install sources to /usr/src/linux-${KERNEL_FULL_VERSION} and manually compile the kernel.
	if ! use build-kernel; then

		# create kernel sources directory
		dodir /usr/src

		# copy kernel sources into place
		cp -a "${S}" "${D}"/usr/src/linux-${KERNEL_FULL_VERSION} || die "failed to install kernel sources"

		# clean-up kernel source tree
		make mrproper || die "failed to prepare kernel sources"

		# copy kconfig into place
		cp "${T}"/.config "${D}"/usr/src/linux-${KERNEL_FULL_VERSION}/.config || die "failed to install kernel config"

	# let Portage handle the compilation, testing and installing of the kernel + initramfs,
	# and optionally installing kernel headers + signing the kernel modules.
	elif use build-kernel; then

		# ... maybe incoporate some [[ ${MERGE_TYPE} != foobar ]] so that headers can
		# be installed on a build server for emerging out-of-tree modules but the end consumer
		# e.g. container doesn't get the headers ...

		# standard target for installing modules to /lib/modules/${KERNEL_FULL_VERSION}
		local targets=( modules_install )

		# ARM / ARM64 requires dtb
		if (use arm || use arm64); then
			targets+=( dtbs_install )
		fi

		emake O="${WORKDIR}"/build "${MAKEARGS[@]}" INSTALL_MOD_PATH="${D}" INSTALL_PATH="${D}"/boot "${targets[@]}"
		install_kernel_and_friends

		local kern_arch=$(tc-arch-kernel)
		dodir /usr/src/linux-${KERNEL_FULL_VERSION}
		mv include scripts "${D}"/usr/src/linux-${KERNEL_FULL_VERSION}/ || die

		dodir /usr/src/linux-${KERNEL_FULL_VERSION}/arch/${kern_arch}
		mv arch/${kern_arch}/include "${D}"/usr/src/linux-${KERNEL_FULL_VERSION}/arch/${kern_arch}/ || die

		# some arches need module.lds linker script to build external modules
		if [[ -f arch/${kern_arch}/kernel/module.lds ]]; then
			mv arch/${kern_arch}/kernel/module.lds "${D}"/usr/src/linux-${KERNEL_FULL_VERSION}/arch/${kern_arch}/kernel/
		fi

		# remove everything but Makefile* and Kconfig*
		find -type f '!' '(' -name 'Makefile*' -o -name 'Kconfig*' ')' -delete || die
		find -type l -delete || die
		cp -p -R * "${D}"/usr/src/linux-${KERNEL_FULL_VERSION}/ || die

		# todo mod_prep
		find "${WORKDIR}"/mod_prep -type f '(' -name Makefile -o -name '*.[ao]' -o '(' -name '.*' -a -not -name '.config' ')' ')' -delete || die
		rm -rf "${WORKDIR}"/mod_prep/source
		cp -p -R "${WORKDIR}"/mod_prep/* "${D}"/usr/src/linux-${KERNEL_FULL_VERSION}

		# copy kconfig into place
		cp "${T}"/.config "${D}"/usr/src/linux-${KERNEL_FULL_VERSION}/.config || die "failed to install kconfig"

		# module symlink fix-up:
		rm -rf "${D}"/lib/modules/${KERNEL_FULL_VERSION}/source || die "failed to remove old kernel source symlink"
		rm -rf "${D}"/lib/modules/${KERNEL_FULL_VERSION}/build || die "failed to remove old kernel build symlink"

		# Set-up module symlinks:
		ln -s /usr/src/linux-${KERNEL_FULL_VERSION} "${D}"/lib/modules/${KERNEL_FULL_VERSION}/source || die "failed to create kernel source symlink"
		ln -s /usr/src/linux-${KERNEL_FULL_VERSION} "${D}"/lib/modules/${KERNEL_FULL_VERSION}/build || die "failed to create kernel build symlink"

		# Install System.map, Module.symvers and bzImage - required for building out-of-tree kernel modules:
		cp "${WORKDIR}"/build/System.map "${D}"/usr/src/linux-${KERNEL_FULL_VERSION}/ || die "failed to install System.map"
		cp "${WORKDIR}"/build/Module.symvers "${D}"/usr/src/linux-${KERNEL_FULL_VERSION}/ || die "failed to install Module.symvers"
		cp "${WORKDIR}"/build/arch/x86/boot/bzImage "${D}"/usr/src/linux-${KERNEL_FULL_VERSION}/arch/x86/boot/bzImage || die "failed to install bzImage"

		# USE=sign-modules depends on the scripts directory being available
		if use sign-modules; then
			for kmod in $(find "${D}"/lib/modules -iname *.ko); do
				# $certs_dir defined previously in this function.
				"${WORKDIR}"/build/scripts/sign-file sha512 ${certs_dir}/signing_key.pem ${certs_dir}/signing_key.x509 ${kmod} || die "failed to sign kernel modules"
			done
			# install the sign-file executable for future use.
			exeinto /usr/src/linux-${KERNEL_FULL_VERSION}/scripts
			doexe "${WORKDIR}"/build/scripts/sign-file
		fi
	fi
}

pkg_postinst() {

	# if USE=symlink...
	if use symlink; then
		# delete the existing symlink if one exists
		if [[ -h "${ROOT}"/usr/src/linux ]]; then
			rm "${ROOT}"/usr/src/linux || die "failed to delete existing /usr/src/linux symlink"
		fi
		# and now symlink the newly installed sources
		ewarn ""
		ewarn "WARNING... WARNING... WARNING"
		ewarn ""
		ewarn "/usr/src/linux symlink automatically set to linux-${KERNEL_FULL_VERSION}"
		ewarn ""
		ln -sf "${ROOT}"/usr/src/linux-${KERNEL_FULL_VERSION} "${ROOT}"/usr/src/linux || die "failed to create /usr/src/linux symlink"
	fi

	# rebuild the initramfs on post_install
	if use build-kernel; then

		# setup dirs for genkernel
		mkdir -p "${WORKDIR}"/genkernel/{tmp,cache,log} || die "failed to create setup directories for genkernel"

		genkernel \
			--color \
			--makeopts="${MAKEOPTS}" \
			--logfile="${WORKDIR}/genkernel/log/genkernel.log" \
			--cachedir="${WORKDIR}/genkernel/cache" \
			--tmpdir="${WORKDIR}/genkernel/tmp" \
			--kernel-config="/boot/config-${KERNEL_FULL_VERSION}" \
			--kerneldir="/usr/src/linux-${KERNEL_FULL_VERSION}" \
			--kernel-outputdir="/usr/src/linux-${KERNEL_FULL_VERSION}" \
			--all-ramdisk-modules \
			--busybox \
			--compress-initramfs \
			--compress-initramfs-type="xz" \
			$(usex btrfs "--btrfs" "--no-btrfs") \
			$(usex debug "--loglevel=5" "--loglevel=1") \
			$(usex firmware "--firmware" "--no-firmware") \
			$(usex luks "--luks" "--no-luks") \
			$(usex lvm "--lvm" "--no-lvm") \
			$(usex mdadm "--mdadm" "--no-mdadm") \
			$(usex mdadm "--mdadm-config=/etc/mdadm.conf" "") \
			$(usex microcode "--microcode-initramfs" "--no-microcode-initramfs") \
			$(usex udev "--udev-rules" "--no-udev-rules") \
			$(usex zfs "--zfs" "--no-zfs") \
			initramfs || die "failed to build initramfs"
	fi

	# warn about the issues with running a hardened kernel
	if use hardened; then
		ewarn ""
		ewarn "Hardened patches have been applied to the kernel and kconfig options have been set."
		ewarn "These kconfig options and patches change kernel behavior."
		ewarn ""
		ewarn "Changes include:"
		ewarn "    Increased entropy for Address Space Layout Randomization"
		if ! use clang; then
			ewarn "    GCC plugins"
		fi
		ewarn "    Memory allocation"
		ewarn "    ... and more"
		ewarn ""
		ewarn "These changes will stop certain programs from functioning"
		ewarn "e.g. VirtualBox, Skype"
		ewarn "Full information available in $DOCUMENTATION"
		ewarn ""
	fi

	if use sign-modules; then
		ewarn "This kernel will ALLOW non-signed modules to be loaded with a WARNING."
		ewarn "To enable strict enforcement, YOU MUST add module.sig_enforce=1 as a kernel boot parameter"
	fi
}

pkg_postrm() {

	# these clean-ups only apply if USE=build-kernel
	if use build-kernel; then

		# clean-up the generated initramfs for this kernel ...
		if [[ -f "${ROOT}"/boot/initramfs-${KERNEL_FULL_VERSION}.img ]]; then
			rm -f "${ROOT}"/boot/initramfs-${KERNEL_FULL_VERSION}.img || die "failed to remove initramfs-${KERNEL_FULL_VERSION}.img"
		fi
	fi
}
