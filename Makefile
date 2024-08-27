SUDO := $(shell [ $(shell id -u) -ne 0 ] && echo sudo)

DEPS_DIR = deps
BIN_DIR  = bin

all: initramfs

clean:
	@echo "Removing docker builder"
	docker buildx rm builder >/dev/null 2>&1 || :

	@echo "Removing SEV-SNP dependencies"
	$(SUDO) rm -rf $(DEPS_DIR)

	@echo "Removing binaries"
	$(SUDO) rm -rf $(BIN_DIR)

	@echo "Removing artifacts"
	$(SUDO) rm -rf initramfs.cpio.gz rootfs

# Guest Dependencies

dirs:
	mkdir -p $(DEPS_DIR) $(BIN_DIR)

ovmf:
	wget -q $(shell cat refs/ovmf.txt) -O $(DEPS_DIR)/OVMF.fd
	@echo "$(shell cat refs/ovmf.sha256)  $(DEPS_DIR)/OVMF.fd" | shasum -c

vmlinuz:
	wget -q $(shell cat refs/vmlinuz.txt) -O $(DEPS_DIR)/vmlinuz
	@echo "$(shell cat refs/vmlinuz.sha256)  $(DEPS_DIR)/vmlinuz" | shasum -c

linux-image:
	wget -q $(shell cat refs/linux-image.txt) -O $(DEPS_DIR)/linux-image.deb
	@echo "$(shell cat refs/linux-image.sha256)  $(DEPS_DIR)/linux-image.deb" | shasum -c

ic-gateway:
	wget $(shell cat refs/ic-gateway.txt) -P $(BIN_DIR)
	@echo "$(shell cat refs/ic-gateway.sha256)  $(BIN_DIR)/ic-gateway" | shasum -c

certificate-issuer:
	wget $(shell cat refs/certificate-issuer.txt) -P $(BIN_DIR)
	@echo "$(shell cat refs/certificate-issuer.sha256)  $(BIN_DIR)/certificate-issuer.gz" | shasum -c
	@gunzip $(BIN_DIR)/certificate-issuer.gz

vector:
	wget $(shell cat refs/vector.txt) -O $(BIN_DIR)/vector.tar.gz
	@echo "$(shell cat refs/vector.sha256)  $(BIN_DIR)/vector.tar.gz" | shasum -c
	@tar -xzf $(BIN_DIR)/vector.tar.gz -C $(BIN_DIR) --strip-components=3 --wildcards '*/bin/vector'

guest-dependencies: dirs ovmf vmlinuz linux-image certificate-issuer vector

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
