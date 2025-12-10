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
	curl -fsSL --retry 15 --retry-max-time 180 --retry-all-errors -o $(DEPS_DIR)/OVMF.fd $(shell jq '.["ovmf"].url' refs.json)
	@echo "$(shell jq '.["ovmf"].sha256' refs.json)  $(DEPS_DIR)/OVMF.fd" | shasum -c
	@sleep 1

vmlinuz:
	curl -fsSL --retry 15 --retry-max-time 180 --retry-all-errors -o $(DEPS_DIR)/vmlinuz $(shell jq '.["vmlinuz"].url' refs.json)
	@echo "$(shell jq '.["vmlinuz"].sha256' refs.json)  $(DEPS_DIR)/vmlinuz" | shasum -c
	@sleep 1

linux-image:
	curl -fsSL --retry 15 --retry-max-time 180 --retry-all-errors -o $(DEPS_DIR)/linux-image.deb $(shell jq '.["linux-image"].url' refs.json)
	@echo "$(shell jq '.["linux-image"].sha256' refs.json)  $(DEPS_DIR)/linux-image.deb" | shasum -c
	@sleep 1

ic-gateway:
	curl -fsSL --retry 15 --retry-max-time 180 --retry-all-errors -H "Accept: application/octet-stream" -o $(BIN_DIR)/ic-gateway $(shell jq '.["ic-gateway"].url' refs.json)
	@echo "$(shell jq '.["ic-gateway"].sha256' refs.json)  $(BIN_DIR)/ic-gateway" | shasum -c
	@sleep 1

ic-http-lb:
	curl -fsSL --retry 15 --retry-max-time 180 --retry-all-errors -H "Accept: application/octet-stream" -o $(BIN_DIR)/ic-http-lb $(shell jq '.["ic-http-lb"].url' refs.json)
	@echo "$(shell jq '.["ic-http-lb"].sha256' refs.json)  $(BIN_DIR)/ic-http-lb" | shasum -c
	@sleep 1

vector:
	curl -fsSL --retry 15 --retry-max-time 180 --retry-all-errors -o $(BIN_DIR)/vector.tar.gz $(shell jq '.["vector"].url' refs.json)
	@echo "$(shell jq '.["vector"].sha256' refs.json)  $(BIN_DIR)/vector.tar.gz" | shasum -c
	@tar -xzf $(BIN_DIR)/vector.tar.gz -C $(BIN_DIR) --strip-components=3 --wildcards '*/bin/vector'
	@sleep 1

node_exporter:
	curl -fsSL --retry 15 --retry-max-time 180 --retry-all-errors -o $(BIN_DIR)/node_exporter.tar.gz $(shell jq '.["node_exporter"].url' refs.json)
	@echo "$(shell jq '.["node_exporter"].sha256' refs.json)  $(BIN_DIR)/node_exporter.tar.gz" | shasum -c
	@tar -xzf $(BIN_DIR)/node_exporter.tar.gz -C $(BIN_DIR) --strip-components=1 --wildcards '*/node_exporter'
	@sleep 1

guest-dependencies: dirs ovmf vmlinuz linux-image ic-gateway ic-http-lb vector node_exporter

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

pip-sev-snp-measure:
	@pip install $(shell jq '.["sev-snp-measure"].url' refs.json) >/dev/null 2>&1

sev-snp-measure: pip-sev-snp-measure
	@sev-snp-measure \
		--mode snp \
		--vcpus='30' \
  		--vcpu-family=25 \
  		--vcpu-model=1 \
  		--vcpu-stepping=1 \
		--ovmf="$(DEPS_DIR)/OVMF.fd" \
		--kernel="$(DEPS_DIR)/vmlinuz" \
		--initrd='initramfs.cpio.gz' \
		--append='console=ttyS0,115200n8'
