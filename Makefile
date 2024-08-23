IMAGE_MAIN_PATH = usr/bin/main

SUDO := $(shell [ $(shell id -u) -ne 0 ] && echo sudo)

all: initramfs

clean:
	docker buildx rm builder >/dev/null 2>&1 || :
	$(SUDO) rm -rf \
		OVMF.fd vmlinuz linux-image.deb \
		initramfs.cpio.gz rootfs

# Guest Dependencies

ovmf:
	wget -q $(shell cat refs/ovmf.txt) -O OVMF.fd
	@echo "$(shell cat refs/ovmf.sha256)  OVMF.fd" | shasum -c

vmlinuz:
	wget -q $(shell cat refs/vmlinuz.txt) -O vmlinuz
	@echo "$(shell cat refs/vmlinuz.sha256)  vmlinuz" | shasum -c

linux-image:
	wget -q $(shell cat refs/linux-image.txt) -O linux-image.deb
	@echo "$(shell cat refs/linux-image.sha256)  linux-image.deb" | shasum -c

ic-gateway:
	wget $(shell cat refs/ic-gateway.txt)
	@echo "$(shell cat refs/ic-gateway.sha256)  ic-gateway" | shasum -c

guest-dependencies: ovmf vmlinuz linux-image

# Initram disk

builder:
	docker buildx create \
		--use \
		--name builder \
		--platform linux/amd64 \
		--driver docker-container

.PHONY: rootfs
rootfs: builder
	docker buildx build \
		-f Dockerfile \
		--platform linux/amd64 \
		--build-arg SOURCE_DATE_EPOCH=0 \
		--output type=local,dest=rootfs,rewrite-timestamp=true \
			.

	$(SUDO) chown -R root:root rootfs
	$(SUDO) touch -d @0 rootfs

initramfs: clean guest-dependencies rootfs
	$(SUDO) sh -c '\
		cd rootfs && \
		find . \
			| LC_ALL=C sort \
			| cpio -o --reproducible -H newc \
			| gzip \
		> ../initramfs.cpio.gz && \
		cd .. \
	'

shasum:
	@$(SUDO) shasum -a256 initramfs.cpio.gz

pip-sev-snp-measure:
	@pip install $(shell cat refs/sev-snp-measure.txt) >/dev/null 2>&1

sev-snp-measure: pip-sev-snp-measure
	@sev-snp-measure \
		--mode snp \
		--vcpus='1' \
		--vcpu-type='EPYC-v4' \
		--ovmf='OVMF.fd' \
		--kernel='vmlinuz' \
		--initrd='initramfs.cpio.gz' \
		--append='console=ttyS0'
