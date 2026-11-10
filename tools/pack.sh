#!/bin/sh
#
# usage: $0 version windows.iso virtio.iso oem/ dest/ xmlpath [local/]
#
set -eu

PROGNAME=$(basename -- "${0}")
PROGBASE=$(d=$(dirname -- "${0}"); cd "${d}" && pwd)
PROJROOT=$(cd "${PROGBASE}/.." && pwd)

VERSION="${1}"
WINDOWS="${2}"
VIRTIO="${3}"
OEM=$(cd "${4}" && pwd)
DESTDIR=$(cd "${5}" && pwd)
XMLPATH="${6}"
LOCAL=
[ X = X"${7:-}" ] || LOCAL=$(cd "${7}" && pwd)

# -------------------------------------------------------------------- #

TMPDIR="${PROJROOT}/tmp/"

[ -d "${DESTDIR}" ]
[ -d "${TMPDIR}" ] || mkdir "${TMPDIR}"

WINFILE=$(basename "${WINDOWS}")
case "${WINDOWS}" in
/var/lib/incus/images/*)
	# The ISO lives on the incusd host, not here.
	WINDIR="${WINDOWS%/*}"
	;;
*)
	WINDIR=$(d=$(dirname -- "${WINDOWS}"); cd "${d}" && pwd)
	;;
esac
VIRTIOFILE=$(basename "${VIRTIO}")
VIRTIODIR=$(d=$(dirname -- "${VIRTIO}"); cd "${d}" && pwd)

if [ X != X$(ls "${DESTDIR}") ]; then
	printf 'error: destination directory must be empty\n' >&2
	exit 1
fi

# -------------------------------------------------------------------- #

name=build$(head -c6 /dev/urandom | od -tx1 -vAn | xargs printf %s)
cleanup() {
	incus image rm "${name}" || :
	incus delete -f "${name}" || :
	if [ X != X"${IMAGES_VOL:-}" ]; then
		incus storage volume file delete "${IMAGES_VOL%%/*}" \
			"${IMAGES_VOL##*/}/isos/${WINFILE}" || :
		incus storage volume file delete "${IMAGES_VOL%%/*}" \
			"${IMAGES_VOL##*/}/isos/unattended-${VERSION}.iso" || :
	fi
}
trap cleanup EXIT INT QUIT TERM

# -------------------------------------------------------------------- #
# virtio - repack

printf '[+] Repacking ISO with unattended data\n'

rm -rf "${TMPDIR}/virtio-win-${VERSION}/"
xorriso -report_about SORRY -osirrox on -indev "${VIRTIODIR}/${VIRTIOFILE}" -extract / "${TMPDIR}/virtio-win-${VERSION}/"
find "${TMPDIR}/virtio-win-${VERSION}/" -type d -exec chmod u+rwx {} \;

cp -R "${OEM}" "${TMPDIR}/virtio-win-${VERSION}/OEM/"
cp "${XMLPATH}" "${TMPDIR}/virtio-win-${VERSION}/"
[ X = X"${LOCAL}" ] || cp -R "${LOCAL}" "${TMPDIR}/virtio-win-${VERSION}/local/"

# strip viosock driver path from staged unattend if absent in the virtio iso
if [ ! -d "${TMPDIR}/virtio-win-${VERSION}/viosock" ]; then
	printf '[+] viosock not present in virtio iso, stripping from unattend\n'
	# read/transform/write-back instead of sed -i, whose -i semantics
	# differ between GNU and BSD sed
	_xml="${TMPDIR}/virtio-win-${VERSION}/$(basename "${XMLPATH}")"
	sed '/<!-- VIOSOCK_BEGIN -->/,/<!-- VIOSOCK_END -->/d' "${_xml}" >"${_xml}.new"
	mv "${_xml}.new" "${_xml}"
fi

rm -f "${DESTDIR}/unattended-${VERSION}.iso"
xorriso -as mkisofs -o "${DESTDIR}/unattended-${VERSION}.iso" -R -J -V STUFF "${TMPDIR}/virtio-win-${VERSION}/"

# If the Windows ISO came from a storage volume, the unattended ISO has to
# follow it: incusd can only read what is on its own host.
if [ X != X"${IMAGES_VOL:-}" ]; then
	printf '[+] Pushing unattended ISO to %s\n' "${IMAGES_VOL}"
	incus storage volume file push "${DESTDIR}/unattended-${VERSION}.iso" \
		"${IMAGES_VOL%%/*}" "${IMAGES_VOL##*/}/isos/unattended-${VERSION}.iso" --create-dirs
	ATTENDED=/var/lib/incus/images/isos/unattended-${VERSION}.iso
else
	ATTENDED="${DESTDIR}/unattended-${VERSION}.iso"
fi

# -------------------------------------------------------------------- #
# launch VM in LXD

apparmr() {
	cat<<__EOF__
${WINDIR}/${WINFILE} rwk,
${ATTENDED} rwk,
__EOF__
}

printf '[+] Launching the VM\n'

incus init "${name}" --empty --vm -c security.secureboot=false -c limits.cpu=4 -c limits.memory=8GB -c image.os=windows -d root,size=30GiB
incus config device set "${name}" root io.bus=virtio-blk
incus config device add "${name}" iso disk source="${WINDIR}/${WINFILE}" boot.priority=10
incus config device add "${name}" incusagent disk source="agent:config"
apparmr | incus config set "${name}" raw.apparmor=-
printf -- '-drive file=%s,index=0,media=cdrom,if=ide -drive file=%s,index=1,media=cdrom,if=ide\n' "${WINDIR}/${WINFILE}" "${ATTENDED}" | incus config set "${name}" raw.qemu=-

if [ X2008 = X"${VERSION}" ]; then
	incus config set "${name}" security.csm=true
fi

if [ X11e = X"${VERSION}" ]; then
	incus config device add "${name}" tpm tpm
	incus config device set "${name}" root size=60GiB
	# Win11 Setup gates install on Secure Boot enabled (and the 11e
	# autounattend has no LabConfig bypass). Enable it on the build VM
	# only -- the resulting image clones fine with secureboot=false later.
	incus config set "${name}" security.secureboot=true
fi

python3 "${PROGBASE}/click.py" "${name}"

printf '[+] Converting the VM to an image\n'
incus publish "${name}" --alias "${name}" --compression none requirements.cdrom_agent=true

printf '[+] Exporting the image\n'
incus image export "${name}" "${DESTDIR}"

printf '[+] Extracting disk.qcow2\n'
# extract then rename instead of tar --transform, which is GNU-only
cat "${DESTDIR}"/*.tar | tar -C "${DESTDIR}" -xf- rootfs.img
mv "${DESTDIR}/rootfs.img" "${DESTDIR}/disk.qcow2"
# incus's disk.qcow2 file is not readable (mode=0)
chmod 0644 "${DESTDIR}/disk.qcow2"
rm -f "${DESTDIR}"/*.tar

printf '[+] Image created\n'
