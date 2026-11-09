# DFINITY HTTP Gateway for the Internet Computer Protocol

This repository builds a minimal, deterministic, and verifiable HTTP Gateway for the
[Internet Computer Protocol (ICP)](https://internetcomputer.org), designed for deployment
in confidential computing environments such as AMD SEV-SNP trusted execution environments.

The HTTP Gateway is in production use by the DFINITY Foundation, serving traffic for
`ic0.app`, `icp0.io`, `icp-api.io`, and all custom domains (e.g., `internetcomputer.org`).

## Releases

Each [release](https://github.com/dfinity/http-gateway-release/releases) includes the following artifacts:

- `initramfs`
- `vmlinuz`
- `OVMF.fd`
- and an SEV-SNP measurement assuming a configuration with 30 vCPUs

### `initramfs`

A custom initramfs image that includes:

- `ic-gateway` from the [ic-gateway repository](https://github.com/dfinity/ic-gateway)
- `ic-http-lb` from the [ic-http-lb repository](https://github.com/dfinity/ic-http-lb)
- `node-exporter` for system-level metrics
- `runit` a lightweight init system and service supervisor
- `chrony` for time synchronization

### `vmlinuz`

- Linux kernel image from the official Debian [`linux-image-cloud-amd64`](https://packages.debian.org/trixie/linux-image-cloud-amd64) package, pinned to the [snapshot.debian.org](https://snapshot.debian.org) timestamp set in the `Dockerfile`

### `OVMF.fd`

- UEFI firmware file for booting in a virtualized environment: the AMD SEV-SNP build of OVMF (`OVMF.amdsev.fd`) from the official Debian [`ovmf-amdsev`](https://packages.debian.org/forky/ovmf-amdsev) package, pinned to the same [snapshot.debian.org](https://snapshot.debian.org) timestamp as the kernel

## Remote Attestation of SEV-SNP-enabled HTTP Gateways

See [Attestation Guide](attestation-guide.md) for instructions on how to remotely attest
and verify the SEV-SNP-enabled HTTP Gateways.

## License

This project is licensed under the [Apache License 2.0](LICENSE).

## Contributing

This repository does not accept external contributions at this time.
