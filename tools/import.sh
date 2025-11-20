#!/bin/sh
#
# Import an LXD VM image
#
set -eu

PROGBASE=$(d=$(dirname -- "${0}"); cd "${d}" && pwd)
PROGNAME=$(basename -- "${0}")

usage() {
	printf 'usage: %s [-h] dir\n' "${PROGNAME}"
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
	shift $(( OPTIND + 1 ))
done

[ X-- != X"${1:-}" ] || shift

if [ 1 -ne $# ]; then
	usage >&2
	exit 1
fi

# -------------------------------------------------------------------- #

n=$(basename -- "${1}")
exec incus image import "${1}/incus.tar.xz" "${1}/disk.qcow2" requirements.cdrom_agent=true \
	--alias "${n}"
