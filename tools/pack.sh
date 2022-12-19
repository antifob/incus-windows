#!/bin/sh
#
# usage: $0 version windows.iso virtio.iso local/ dest/
#
set -eu

PROGNAME=$(basename -- "${0}")
PROGBASE=$(d=$(dirname -- "${0}"); cd "${d}" && pwd)
PROJROOT=$(cd "${PROGBASE}/.." && pwd)

VERSION="${1}"
WINDOWS="${2}"
VIRTIO="${3}"
LOCAL=$(cd "${4}" && pwd)
DESTDIR=$(cd "${5}" && pwd)

# -------------------------------------------------------------------- #

TMPDIR="${PROJROOT}/tmp/"

[ -d "${DESTDIR}" ]
[ -d "${TMPDIR}" ] || mkdir "${TMPDIR}"

WINFILE=$(basename "${WINDOWS}")
WINDIR=$(d=$(dirname -- "${WINDOWS}"); cd "${d}" && pwd)
VIRTIOFILE=$(basename "${VIRTIO}")
VIRTIODIR=$(d=$(dirname -- "${VIRTIO}"); cd "${d}" && pwd)

if [ X != X$(ls "${DESTDIR}") ]; then
	printf 'error: destination directory must be empty\n' >&2
	exit 1
fi

# -------------------------------------------------------------------- #

name=build$(head -c6 /dev/urandom | od -tx1 -vAn | xargs printf %s)
cleanup() {
	if [ X2008 != X"${VERSION}" ]; then
		lxc image rm "${name}"
		lxc delete -f "${name}"
	fi
}
trap cleanup EXIT INT QUIT TERM

# -------------------------------------------------------------------- #
# virtio - repack

rm -rf "${TMPDIR}/virtio-win-${VERSION}/"
xorriso -report_about SORRY -osirrox on -indev "${VIRTIODIR}/${VIRTIOFILE}" -extract / "${TMPDIR}/virtio-win-${VERSION}/"
find "${TMPDIR}/virtio-win-${VERSION}/" -type d -exec chmod u+rwx {} \;

cp -R "${LOCAL}" "${TMPDIR}/virtio-win-${VERSION}/local/"
cp "${PROJROOT}/unattend/${VERSION}/Autounattend.xml" "${TMPDIR}/virtio-win-${VERSION}/"

rm -f "${DESTDIR}/unattended-${VERSION}.iso"
xorriso -as mkisofs -o "${DESTDIR}/unattended-${VERSION}.iso" -R -J -V STUFF "${TMPDIR}/virtio-win-${VERSION}/"

[ X2008 != X"${VERSION}" ] || exit 0

# -------------------------------------------------------------------- #
# launch VM in LXD

apparmr() {
	cat<<__EOF__
${WINDIR}/${WINFILE} rwk,
${DESTDIR}/unattended-${VERSION}.iso rwk,
__EOF__
}

[ X = X"${LXD_STORAGE:-}" ] || LXD_STORAGE="-s ${LXD_STORAGE}"

lxc init "${name}" --empty --vm -c security.secureboot=false -c limits.cpu=4 -c limits.memory=8GB ${LXD_STORAGE:-}
if [ X = X"${LXD_STORAGE:-}" ]; then
	lxc config device override "${name}" root size=30GiB
else
	lxc config device set "${name}" root size=30GiB
fi
lxc config device add "${name}" iso disk source="${WINDIR}/${WINFILE}" boot.priority=10
apparmr | lxc config set "${name}" raw.apparmor -
printf -- '-drive file=%s,index=0,media=cdrom,if=ide -drive file=%s,index=1,media=cdrom,if=ide\n' "${WINDIR}/${WINFILE}" "${DESTDIR}/unattended-${VERSION}.iso" | lxc config set "${name}" raw.qemu -

python3 "${PROGBASE}/click.py" "${name}"

printf '[+] Converting VM to image\n'
lxc publish "${name}" --alias "${name}" --compression none

printf '[+] Exporting image\n'
lxc image export "${name}" "${DESTDIR}"

printf '[+] Extracting disk.qcow2\n'
cat "${DESTDIR}"/*.tar | tar -C "${DESTDIR}" -f- -x --transform s/rootfs.img/disk.qcow2/ rootfs.img
rm -f "${DESTDIR}"/*.tar

printf '[+] Image created\n'
