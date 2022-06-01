.POSIX:

VIRTIO_SHA512=	63e927f2bd5039ade7f7f29ebc5fe34f8c6bfa3af82c0f66ba43b5c68b523fdfe91c76099b4aa511fe820be616fa66619b601fe956f05e46e4435dd1e343420e


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
2012: virtio-win
	${RUN} 2012
2016: virtio-win
	${RUN} 2016
2019: virtio-win
	${RUN} 2019
2022: virtio-win
	${RUN} 2022


virtio-win:
	if [ ! -f ./isos/virtio-win.iso ]; then \
		curl -L https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/latest-virtio/virtio-win.iso >./isos/virtio-win.iso; \
	fi
	[ X'${VIRTIO_SHA512}' = X$$(sha512sum ./isos/virtio-win.iso | cut -d' ' -f1) ]
	[ -d ./tmp/ ] || mkdir ./tmp/
	xorriso -report_about SORRY -osirrox on -indev ./isos/virtio-win.iso -extract / ./tmp/virtio-win
	find ./tmp/virtio-win/ -type d -exec chmod u+rwx {} \;
