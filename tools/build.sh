#!/bin/sh
#
# Build a VM image.
#
set -eu

PROGBASE=$(d=$(dirname -- "${0}"); cd "${d}" && pwd)
PROGNAME=$(basename -- "${0}")

usage() {
	printf 'usage: %s [-h] version\n' "${PROGNAME}"
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

[ -d ./tmp/ ] || mkdir ./tmp/

TMPDIR=$(pwd)/tmp make "${1}"
sh "${PROGBASE}/tools/mkmeta" "${1}" >"./output/win${1}/lxd.tar.xz"
