# DFINITY Internet Computer HTTP Gateway

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
- `certificate-issuer` for custom domain support from the [main IC repository](https://github.com/dfinity/ic/tree/master/rs/boundary_node/certificate_issuance/certificate_issuer)
- `vector` for logging
- `node-exporter` for system-level metrics
- `runit` a lightweight init system and service supervisor

### `vmlinuz`

- Linux kernel image, sourced from the [SEV-SNP dependencies repository](https://github.com/dfinity/sev-snp-deps)

### `OVMF.fd`

- UEFI firmware file for booting in a virtualized environment, also sourced from the [SEV-SNP dependencies repository](https://github.com/dfinity/sev-snp-deps)

## License

This project is licensed under the [Apache License 2.0](LICENSE).

## Contributing

This repository does not accept external contributions at this time.
