.POSIX:

VIRTIO_ARCHIVE= 	https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/archive-virtio/
VIRTIO_VERSION=		0.1.217
VIRTIO_REVISION=	-2
VIRTIO_SHA256=		8d17ae343e60f0463ce0393035c6efe209d213cf1938d0a25ce09fc55a666e7b


# ${DLISO} url filename sha256
DLISO=	dliso() { \
		set -x; \
		[ -d ./isos/ ] || mkdir ./isos/; \
		if [ ! -f "./isos/$$2" ]; then \
			curl -Lso "./isos/$$2" "$$1"; \
			if [ X$$3 != X$$(sha256sum "./isos/$$2" | cut -d' ' -f1) ]; then \
				rm -f "./isos/$$2"; \
				printf 'error: download failed\n' >&2; \
				exit 1; \
			fi; \
		fi; \
	}; dliso

# ${DLWIN} version
DLWIN=	dlwin() { \
		set -x; \
		u=$$(grep "^$$1 " urls.txt | cut -d' ' -f2); \
		b=$$(basename "$$u"); \
		h=$$(grep " $$b" isos.sha256 | cut -d' ' -f1); \
		${DLISO} "$$u" "$$b" "$$h"; \
	}; dlwin


BUILD=	build() { \
		set -x; \
		if [ -d ./output/win$$1/ ]; then \
			printf 'error: ./output/win%s/ already exists\n' "$$1" >&2; \
			exit 1; \
		fi; \
		mkdir -p ./output/win$$1/; \
		sh ./tools/pack.sh \
			"$$1" \
			./isos/$$(basename $$(awk "/^$$1 / {print \$$2;}" urls.txt)) \
			./isos/virtio-win.iso \
			./local/ \
			./output/win$$1/; \
		sh ./tools/mkmeta $$1 >./output/win$$1/lxd.tar.xz; \
	}; build


all: help
help:
	@printf 'targets:\n\n'
	@printf ' 10e\tWindows 10 Enterprise\n'
	@printf ' 2012\tWindows Server 2012 R2\n'
	@printf ' 2016\tWindows Server 2016\n'
	@printf ' 2019\tWindows Server 2019\n'
	@printf ' 2022\tWindows Server 2022\n'
	@printf '\n'


10e: dl-10e dl-virtio
	@${BUILD} 10e
2012: dl-2012 dl-virtio
	@${BUILD} 2012
2016: dl-2016 dl-virtio
	@${BUILD} 2016
2019: dl-2019 dl-virtio
	@${BUILD} 2019
2022: dl-2022 dl-virtio
	@${BUILD} 2022

dl-10e:
	@${DLWIN} 10e
dl-2008:
	@${DLWIN} 2008
dl-2012:
	@${DLWIN} 2012
dl-2016:
	@${DLWIN} 2016
dl-2019:
	@${DLWIN} 2019
dl-2022:
	@${DLWIN} 2022

dl-virtio:
	@${DLISO} '${VIRTIO_ARCHIVE}/virtio-win-${VIRTIO_VERSION}${VIRTIO_REVISION}/virtio-win.iso' 'virtio-win.iso' '${VIRTIO_SHA256}'
