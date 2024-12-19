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
	wget -q $(shell jq '.["ovmf"].url' refs.json) -O $(DEPS_DIR)/OVMF.fd
	@echo "$(shell jq '.["ovmf"].sha256' refs.json)  $(DEPS_DIR)/OVMF.fd" | shasum -c

vmlinuz:
	wget -q $(shell jq '.["vmlinuz"].url' refs.json) -O $(DEPS_DIR)/vmlinuz
	@echo "$(shell jq '.["vmlinuz"].sha256' refs.json)  $(DEPS_DIR)/vmlinuz" | shasum -c

linux-image:
	wget -q $(shell jq '.["linux-image"].url' refs.json) -O $(DEPS_DIR)/linux-image.deb
	@echo "$(shell jq '.["linux-image"].sha256' refs.json)  $(DEPS_DIR)/linux-image.deb" | shasum -c

ic-gateway:
	wget $(shell jq '.["ic-gateway"].url' refs.json) -P $(BIN_DIR)
	@echo "$(shell jq '.["ic-gateway"].sha256' refs.json)  $(BIN_DIR)/ic-gateway" | shasum -c

certificate-issuer:
	wget $(shell jq '.["certificate-issuer"].url' refs.json) -P $(BIN_DIR)
	@echo "$(shell jq -r '.["certificate-issuer"].sha256' refs.json)  $(BIN_DIR)/certificate-issuer.gz" | shasum -c
	@gunzip $(BIN_DIR)/certificate-issuer.gz

canary-proxy:
	wget $(shell jq '.["canary-proxy"].url' refs.json) -P $(BIN_DIR)
	@echo "$(shell jq -r '.["canary-proxy"].sha256' refs.json)  $(BIN_DIR)/canary-proxy.gz" | shasum -c
	@gunzip $(BIN_DIR)/canary-proxy.gz

vector:
	wget $(shell jq '.["vector"].url' refs.json) -O $(BIN_DIR)/vector.tar.gz
	@echo "$(shell jq '.["vector"].sha256' refs.json)  $(BIN_DIR)/vector.tar.gz" | shasum -c
	@tar -xzf $(BIN_DIR)/vector.tar.gz -C $(BIN_DIR) --strip-components=3 --wildcards '*/bin/vector'

node_exporter:
	wget $(shell jq '.["node_exporter"].url' refs.json) -O $(BIN_DIR)/node_exporter.tar.gz
	@echo "$(shell jq '.["node_exporter"].sha256' refs.json)  $(BIN_DIR)/node_exporter.tar.gz" | shasum -c
	@tar -xzf $(BIN_DIR)/node_exporter.tar.gz -C $(BIN_DIR) --strip-components=1 --wildcards '*/node_exporter'

guest-dependencies: dirs ovmf vmlinuz linux-image ic-gateway canary-proxy certificate-issuer vector node_exporter

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
	@pip install $(shell jq '.["sev-snp-measure"].url' refs.json) >/dev/null 2>&1

sev-snp-measure: pip-sev-snp-measure
	@sev-snp-measure \
		--mode snp \
		--vcpus='1' \
		--vcpu-type='EPYC-v4' \
		--ovmf="$(DEPS_DIR)/OVMF.fd" \
		--kernel="$(DEPS_DIR)/vmlinuz" \
		--initrd='initramfs.cpio.gz' \
		--append='console=ttyS0'
