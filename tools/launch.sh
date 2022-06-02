#!/bin/sh
#
# Start an LXD VM from an image.
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

lxc init "win${1}" "win${1}" -c security.secureboot=false
lxc config device add "win${1}" cidata disk source=cloud-init:config
exec lxc start "win${1}"
