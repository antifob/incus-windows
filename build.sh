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
	printf 'usage: %s [-h] target\n' "${PROGNAME}"
}

while getopts h- argv; do
	case "${argv}" in
	h)	usage
		exit 0
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

if [ 1 -ne $# ]; then
	usage >&2
	targets=$(cut -d' ' -f1 "${PROGBASE}/urls.txt" | paste -sd' ')
	printf 'available targets: %s\n' "${targets}"
	exit 1
fi

# -------------------------------------------------------------------- #

die() {
	printf -- "${@}" >&2
	exit 1
}


# sanity check on the target
if echo "${1}" | grep -q -- "^[a-z0-9-]$"; then
	printf 'error: invalid target name\n' >&2
	exit 1
fi

# verify the target
url=$(awk "/^${1} /{print \$2;}" "${PROGBASE}/urls.txt")
[ X != X"${url}" ] || die 'error: unable to locate URL for target: %s\n' "${1}"

fname=$(basename "${url}")
sha=$(awk "/ ${fname}$/{print \$1;}" "${PROGBASE}/isos.sha256")
[ X != X"${sha}" ] || die 'error: unable to locate SHA-256 digest for %s\n' "${fname}"

# -------------------------------------------------------------------- #

ISODIR="${ISODIR:-./isos}"
OUTDIR="${OUTDIR:-./output/win${1}}"


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

dliso "${VIRTIO_ARCHIVE}/virtio-win-${VIRTIO_VERSION}${VIRTIO_REVISION}/virtio-win.iso" virtio-win.iso "${VIRTIO_SHA256}"


printf '[+] Downloading Windows ISO file\n'

dliso "${url}" "${fname}" "${sha}"


printf '[+] Building image\n'

[ ! -d "${OUTDIR}" ] || die 'error: %s already exists\n' "${OUTDIR}"
mkdir -p "${OUTDIR}"

sh "${PROGBASE}/tools/pack.sh" \
	"$1" \
	"${ISODIR}/${fname}" \
	"${ISODIR}/virtio-win.iso" \
	"${PROGBASE}/local/" \
	"${OUTDIR}"


printf '[+] Generating metadata\n'

exec sh "${PROGBASE}/tools/mkmeta" "${1}" >"${OUTDIR}/incus.tar.xz"

# ==================================================================== #
