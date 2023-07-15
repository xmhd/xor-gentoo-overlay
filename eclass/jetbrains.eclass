# Copyright 2022 SpuneRace Technologies <root@spunerace.org>
# Distributed under the terms of the GNU General Public License v2

# @ECLASS: jetbrains.eclass
# @MAINTAINER: Dave Hughes <xor@spunerace.org>
# @AUTHOR: Dave Hughes <xor@spunerace.org>
# @SUPPORTED_EAPIS: 7 8
# @BLURB: JetBrains IDE common code

case "${EAPI:-0}" in
	0|1|2|3|4|5|6)
		die "Unsupported EAPI=${EAPI:-0} (too old) for ${ECLASS}"
		;;
	7|8)
		;;
	*)
		die "${ECLASS}: EAPI ${EAPI} unsupported."
		;;
esac

if [[ ! ${_JETBRAINS_ECLASS} ]]; then

inherit desktop wrapper xdg-utils

case "${PN}" in
	clion)
		DESCRIPTION="A complete toolset for C and C++ development"
		HOMEPAGE="https://www.jetbrains.com/clion"
		SRC_URI="https://download.jetbrains.com/cpp/CLion-${PV}.tar.gz"
		;;
	datagrip)
		DESCRIPTION="Many databases, one tool"
		HOMEPAGE="https://www.jetbrains.com/datagrip"
		SRC_URI="https://download.jetbrains.com/datagrip/${P}.tar.gz"
		;;
	dataspell)
		DESCRIPTION="The IDE for Professional Data Scientists"
		HOMEPAGE="https://www.jetbrains.com/dataspell"
		SRC_URI="https://download.jetbrains.com/python/${P}.tar.gz"
		;;
	goland)
		DESCRIPTION="TODO"
		HOMEPAGE="https://www.jetbrains.com/goland"
		SRC_URI="https://download.jetbrains.com/go/${P}.tar.gz"
		;;
	idea-community)
		DESCRIPTION="The most intelligent Java IDE"
		HOMEPAGE="https://jetbrains.com/idea"
		SRC_URI="https://download.jetbrains.com/idea/ideaIC-${PV}.tar.gz"
		;;
	idea-ultimate)
		DESCRIPTION="The most intelligent Java IDE"
		HOMEPAGE="https://www.jetbrains.com/idea"
		SRC_URI="https://download.jetbrains.com/idea/ideaIU-${PV}.tar.gz"
		;;
	phpstorm)
		DESCRIPTION="TODO"
		HOMEPAGE="https://www.jetbrains.com/phpstorm"
		SRC_URI="https://download.jetbrains.com/webide/PhpStorm-${PV}.tar.gz"
		;;
	pycharm-community|pycharm-professional)
		DESCRIPTION="Intelligent Python IDE with unique code assistance and analysis"
		HOMEPAGE="https://www.jetbrains.com/pycharm"
		SRC_URI="https://download.jetbrains.com/python/${P}.tar.gz"
		;;
	rider)
		DESCRIPTION="Cross-platform .NET IDE"
		HOMEPAGE="https://www.jetbrains.com/rider"
		SRC_URI="https://download.jetbrains.com/rider/JetBrains.Rider-${PV}.tar.gz"
		;;
	rubymine)
		DESCRIPTION="The most intelligent Ruby and Rails IDE"
		HOMEPAGE="https://www.jetbrains.com/rubymine"
		SRC_URI="https://download.jetbrains.com/ruby/RubyMine-${PV}.tar.gz"
		;;
	webstorm)
		DESCRIPTION="TODO"
		HOMEPAGE="https://www.jetbrains.com/webstorm"
		SRC_URI="https://download.jetbrains.com/webstorm/WebStorm-${PV}.tar.gz"
		;;
	*)
		die "foobar unsupported"
		;;
esac

LICENSE="
	|| (
		JetBrains_Business-4.0
		JetBrains_Classroom-4.0
		JetBrains_Educational-4.2
		JetBrains_OpenSource-4.2
		JetBrains_Personal-4.2
		JetBrains_Community-1.1
	)
	Apache-1.1
	Apache-2.0
	BSD
	BSD-2
	CC0-1.0
	CPL-1.0
	GPL-2-with-classpath-exception
	GPL-3
	ISC
	LGPL-2.1
	LGPL-3
	MIT
	MPL-1.1
	OFL
	PSF-2
	UoI-NCSA
"

SLOT="0"

KEYWORDS=""

IUSE="lldb"

RDEPEND="
	dev-libs/libdbusmenu
	lldb? ( dev-util/lldb )
	media-libs/mesa[X(+)]
	x11-libs/libX11
	x11-libs/libXcomposite
	x11-libs/libXcursor
	x11-libs/libXdamage
	x11-libs/libXext
	x11-libs/libXfixes
	>=x11-libs/libXi-1.3
	>=x11-libs/libXrandr-1.5
"

RESTRICT="bindist mirror splitdebug strip"

QA_PREBUILT="/opt/${PN}/*"

EXPORT_FUNCTIONS pkg_setup src_unpack src_prepare src_install pkg_postinst pkg_postrm

# @FUNCTION: TODO
# @DESCRIPTION: TODO
jetbrains_get_vendor_names() {

	case "${PN}" in
		clion)
			MY_NAME="${PN}"
			MY_NAME_FULL="CLion"
			;;
		datagrip)
			MY_NAME="${PN}"
			MY_NAME_FULL="DataGrip"
			;;
		dataspell)
			MY_NAME="${PN}"
			MY_NAME_FULL="DataSpell"
			;;
		goland)
			MY_NAME="${PN}"
			MY_NAME_FULL="GoLand"
			;;
		idea-community)
			MY_NAME="${PN%-*}"
			MY_NAME_FULL="Intellij IDEA Community"
			;;
		idea-ultimate)	
			MY_NAME="${PN%-*}"
			MY_NAME_FULL="Intellij IDEA Ultimate"
			;;
		phpstorm)
			MY_NAME="${PN}"
			MY_NAME_FULL="PhpStorm"
			;;
		pycharm-community)
			MY_NAME="${PN%-*}"
			MY_NAME_FULL="PyCharm Community"
			;;
		pycharm-professional)
			MY_NAME="${PN%-*}"
			MY_NAME_FULL="PyCharm Professional"
			;;
		rider)
			MY_NAME="${PN}"
			MY_NAME_FULL="Rider"
			;;
		rubymine)
			MY_NAME="${PN}"
			MY_NAME_FULL="RubyMine"
			;;
		webstorm)
			MY_NAME="${PN}"
			MY_NAME_FULL="WebStorm"
			;;
		*)
			die "foobar unsupported"
			;;
	esac
}

# @FUNCTION: TODO
# @DESCRIPTION: TODO
jetbrains_pkg_setup() {
	jetbrains_get_vendor_names
}

# @FUNCTION: jetbrains_src_unpack
# @DESCRIPTION: TODO
jetbrains_src_unpack() {

	case "${PN}" in
		clion)
			unpack ${MY_NAME_FULL}-${PV}.tar.gz
			;;
		datagrip)
			unpack ${P}.tar.gz
			mv "${WORKDIR}"/${MY_NAME_FULL}-${PV} "${WORKDIR}"/${P} || die "unpack failed"
			;;
		dataspell)
			unpack ${P}.tar.gz
			;;
		goland)
			unpack ${P}.tar.gz
			mv "${WORKDIR}"/${MY_NAME_FULL}-${PV} "${WORKDIR}"/${P} || die "unpack failed"
			;;
		idea-community)
			unpack ideaIC-${PV}.tar.gz
			mv "${WORKDIR}"/idea-IC* "${WORKDIR}"/${P} || die "unpack failed"
			;;
		idea-ultimate)
			unpack ideaIU-${PV}.tar.gz 
			mv "${WORKDIR}"/idea-IU* "${WORKDIR}"/${P} || die "unpack failed"
			;;
		phpstorm)
			unpack ${MY_NAME_FULL}-${PV}.tar.gz
			mv "${WORKDIR}"/PhpStorm-* "${WORKDIR}"/${P} || die "unpack failed"
			;;
		pycharm-community)
			unpack ${P}.tar.gz
			;;
		pycharm-professional)
			unpack ${P}.tar.gz
			mv "${WORKDIR}"/pycharm-${PV} "${WORKDIR}"/${P} || die "unpack failed"
			;;
		rider)
			unpack JetBrains.Rider-${PV}.tar.gz
			mv "${WORKDIR}"/JetBrains* "${WORKDIR}"/${P} || die "unpack failed"
			;;
		rubymine)
			unpack ${MY_NAME_FULL}-${PV}.tar.gz
			mv "${WORKDIR}"/RubyMine-* "${WORKDIR}"/${P} || die "unpack failed"
			;;
		webstorm)
			unpack ${MY_NAME_FULL}-${PV}.tar.gz
			mv "${WORKDIR}"/WebStorm-* "${WORKDIR}"/${P} || die "unpack failed"
			;;
		*)
			die "foobar unsupported"
			;;
	esac
}

# @FUNCTION: jetbrains_src_prepare
# @DESCRIPTION: TODO
jetbrains_src_prepare() {
	default

	# remove the bundled JetBrains JDK
	# TODO: jre{64} possibly not required, wait until all other IDEs have been added before removing
	rm -rf {jbr,jre{64}} || die "Failed to remove bundled JetBrains JDK"

	# TODO: purge_files for unneeded native files etc

	# TODO: patchelf --replace-needed on native files
}

# @FUNCTION: jetbrains_src_install
# @DESCRIPTION: TODO
jetbrains_src_install() {
	local install_dir="/opt/${PN}"

	insinto "${install_dir}"
	doins -r *

	find "${D}"/"${install_dir}"/bin/ -type f \( -name "*.sh" -o -name "*.py" \) -exec chmod 755 {} + || die "failed to fperms executable files"

	make_wrapper "${PN}" "${install_dir}"/bin/${MY_NAME}.sh
	newicon bin/${MY_NAME}.svg "${PN}".svg
	make_desktop_entry "${PN}" "${MY_NAME_FULL}" "${PN}" "Development;IDE;"

	# recommended by: https://confluence.jetbrains.com/display/IDEADEV/Inotify+Watches+Limit
	mkdir -p "${D}/etc/sysctl.d/" || die
	echo "fs.inotify.max_user_watches = 524288" > "${D}/etc/sysctl.d/30-${MY_PN}-inotify-watches.conf" || die
}

# @FUNCTION: TODO
# @DESCRIPTION: TODO
jetbrains_pkg_postinst() {
	xdg_icon_cache_update
}

# @FUNCTION: TODO
# @DESCRIPTION: TODO
jetbrains_pkg_postrm() {
	xdg_icon_cache_update
}

	_JETBRAINS_ECLASS=1
fi
