#!/bin/sh
# ==================================================================== #
#
# This file is part of incus-windows.
#
# Copyright 2025 Philippe Grégoire <git@pgregoire.xyz>
#
# ==================================================================== #
set -eu

PROGNAME=$(basename -- "${0}")
PROGBASE=$(d=$(dirname -- "${0}"); cd "${d}" && pwd)

usage() {
	printf 'usage: %s [-h] [-i altiso] [-x xml] target\n' "${PROGNAME}"
}

isopath=
xmlpath=
while getopts hi:x:- argv; do
	case "${argv}" in
	h)	usage
		exit 0
		;;
	i)	isopath="${OPTARG}"
		;;
	x)	xmlpath="${OPTARG}"
		;;
	-)	break
		;;
	*)	usage >&2
		exit 1
		;;
	esac
	shift $(( OPTIND - 1 ))
done

[ X-- != X"${1:-}" ] || shift

targets=$(cut -d' ' -f1 "${PROGBASE}/urls.txt" | paste -sd' ')
if [ 1 -ne $# ] && [ 2 -ne $# ]; then
	usage >&2
	printf 'available targets: %s\n' "${targets}"
	exit 1
fi

# -------------------------------------------------------------------- #

die() {
	printf -- "${@}" >&2
	exit 1
}

VERSION="${1}"

# sanity check on the target
if echo "${VERSION}" | grep -q -- "^[a-z0-9-]$"; then
	printf 'error: invalid target name\n' >&2
	exit 1
fi
if [ ! -f "${PROGBASE}/tools/metas/${VERSION}.in" ]; then
	printf 'error: unknown version\n' >&2
	printf 'available targets: %s\n' "${targets}" >&2
	exit 1
fi

# verify the target
if [ X = X"${isopath}" ]; then
	url=$(awk "/^${VERSION} /{print \$2;}" "${PROGBASE}/urls.txt")
	[ X != X"${url}" ] || die 'error: unable to locate URL for target: %s\n' "${VERSION}"

	fname=$(basename "${url}")
	sha=$(awk "/ ${fname}$/{print \$1;}" "${PROGBASE}/isos.sha256")
	[ X != X"${sha}" ] || die 'error: unable to locate SHA-256 digest for %s\n' "${fname}"
elif [ ! -r "${isopath}" ]; then
	die 'error: not readable: %s\n' "${isopath}"
fi

if [ X = X"${xmlpath}" ]; then
	xmlpath="${PROGBASE}/unattend/${VERSION}/Autounattend.xml"
else
	xmldir=$(d=$(dirname -- "${xmlpath}"); cd "${d}" && pwd)
	xmlfile=$(basename -- "${xmlpath}")
	xmlpath="${xmldir}/${xmlfile}"
fi

if [ ! -r "${xmlpath}" ]; then
	die 'error: not readable: %s\n' "${xmlpath}"
fi

# -------------------------------------------------------------------- #

ISODIR="${ISODIR:-./isos}"
OUTDIR="${OUTDIR:-./output/win${VERSION}}"

# dliso url fname sha256
dliso() {
	[ -d "${ISODIR}" ] || mkdir "${ISODIR}"

	[ -f "${ISODIR}/${2}" ] || curl -fSLo "${ISODIR}/${2}" "${1}"

	if [ X"${3}" != X$(sha256sum "${ISODIR}/${2}" | cut -d' ' -f1) ]; then
		die 'error: hash mismatch for %s\n' "${ISODIR}/${2}"
	fi
}


# source in the virtio references
. "${PROGBASE}/config.sh"


printf '[+] Downloading virtio drivers for Windows\n'

dliso "${VIRTIO_ARCHIVE}/virtio-win-${VIRTIO_VERSION}/virtio-win.iso" "virtio-win-${VIRTIO_VERSION}.iso" "${VIRTIO_SHA256}"


if [ X = X"${isopath}" ]; then
	printf '[+] Downloading Windows ISO file\n'

	dliso "${url}" "${fname}" "${sha}"

	isopath="${ISODIR}/${fname}"
else
	isodir=$(d=$(dirname -- "${isopath}"); cd "${d}" && pwd)
	isofile=$(basename -- "${isopath}")
	isopath="${isodir}/${isofile}"
fi


printf '[+] Building image\n'

[ ! -d "${OUTDIR}" ] || die 'error: %s already exists\n' "${OUTDIR}"
mkdir -p "${OUTDIR}"

shift
sh "${PROGBASE}/tools/pack.sh" \
	"${VERSION}" \
	"${isopath}" \
	"${ISODIR}/virtio-win-${VIRTIO_VERSION}.iso" \
	"${PROGBASE}/oem/" \
	"${OUTDIR}" \
	"${xmlpath}" \
	"${@}"


printf '[+] Generating metadata\n'

exec sh "${PROGBASE}/tools/mkmeta" "${VERSION}" >"${OUTDIR}/incus.tar.xz"

# ==================================================================== #
