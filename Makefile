.POSIX:

VIRTIO_VERSION=		0.1.217
VIRTIO_REVISION=	-2
VIRTIO_SHA512=		34edb8e0b5aacf1ca2fa3ac08a86e91be149d35cfd5f686464cf58239c0b145a06cf241c546195684d8576669462c545af6ba56c1cc870c560f33497bcd43ce1
VIRTIO_ARCHIVE= 	https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/archive-virtio/


RUN=	f() { \
		NAME="win$$1" \
		WINDOWS_VERSION="$$1" \
		ISO_URL=$$(awk "/^$$1 / {print \$$2;}" urls.txt) \
		PACKER_CACHE_DIR=$$(pwd)/isos \
		./packer build windows.json; \
	}; f


all: help
help:
	@printf 'targets:\n\n'
	@printf ' 10e\tWindows 10 Enterprise\n'
	@printf ' 2012\tWindows Server 2012\n'
	@printf ' 2016\tWindows Server 2016\n'
	@printf ' 2019\tWindows Server 2019\n'
	@printf ' 2022\tWindows Server 2022\n'
	@printf '\n'


10e: virtio-win
	${RUN} 10e
#2012: virtio-win
#	${RUN} 2012
2016: virtio-win
	${RUN} 2016
2019: virtio-win
	${RUN} 2019
2022: virtio-win
	${RUN} 2022


virtio-win:
	[ -d ./isos/ ] || mkdir ./isos/
	if [ ! -f ./isos/virtio-win.iso ]; then \
		curl -L '${VIRTIO_ARCHIVE}/virtio-win-${VIRTIO_VERSION}${VIRTIO_REVISION}/virtio-win-${VIRTIO_VERSION}.iso' >./isos/virtio-win.iso; \
	fi
	[ X'${VIRTIO_SHA512}' = X$$(sha512sum ./isos/virtio-win.iso | cut -d' ' -f1) ]
	[ -d ./tmp/ ] || mkdir ./tmp/
	xorriso -report_about SORRY -osirrox on -indev ./isos/virtio-win.iso -extract / ./tmp/virtio-win
	find ./tmp/virtio-win/ -type d -exec chmod u+rwx {} \;
