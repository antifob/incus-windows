VIRTIO_ARCHIVE="${VIRTIO_ARCHIVE:-https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/archive-virtio/}"
# 0.1.262-1 breaks 2012
VIRTIO_VERSION_DEFAULT="${VIRTIO_VERSION_DEFAULT:-0.1.248-1}"
VIRTIO_SHA256_DEFAULT="${VIRTIO_SHA256_DEFAULT:-d5b5739cf297f0538d263e30678d5a09bba470a7c6bcbd8dff74e44153f16549}"
# VIRTIO 0.1.285-1 vsock drivers needed for incus agent => 6.22
VIRTIO_VERSION_6_22="${VIRTIO_VERSION_6_22:-0.1.285-1}"
VIRTIO_SHA256_6_22="${VIRTIO_SHA256_6_22:-e14cf2b94492c3e925f0070ba7fdfedeb2048c91eea9c5a5afb30232a3976331}"

# auto-select virtio pack based on local incus version (6.22+ needs vsock)
if [ -z "${VIRTIO_VERSION:-}" ] && command -v incus >/dev/null 2>&1; then
	_iv=$(incus version 2>/dev/null | awk '/^Client version:/ {print $3; exit}')
	if [ -n "${_iv}" ] \
	&& [ "$(printf '6.22\n%s\n' "${_iv}" | sort -V | head -n1)" = "6.22" ]; then
		VIRTIO_VERSION="${VIRTIO_VERSION_6_22}"
		VIRTIO_SHA256="${VIRTIO_SHA256_6_22}"
	fi
	unset _iv
fi

VIRTIO_VERSION="${VIRTIO_VERSION:-${VIRTIO_VERSION_DEFAULT}}"
VIRTIO_SHA256="${VIRTIO_SHA256:-${VIRTIO_SHA256_DEFAULT}}"
