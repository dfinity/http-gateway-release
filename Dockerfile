# syntax=docker/dockerfile:1

FROM debian:trixie-20240513-slim

ENV DEBIAN_FRONTEND=noninteractive

# https://snapshot.debian.org/archive/debian/20240515T144351Z/
ARG SNAPSHOT=20240515T144351Z

RUN \
  --mount=type=cache,target=/var/cache/apt,sharing=locked \
  --mount=type=cache,target=/var/lib/apt,sharing=locked \
    : "Enabling snapshot" && \
    sed -i -e '/Types: deb/ a\Snapshot: true' /etc/apt/sources.list.d/debian.sources && \
    : "Enabling cache" && \
    rm -f /etc/apt/apt.conf.d/docker-clean && \
    echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' >/etc/apt/apt.conf.d/keep-cache && \
    : "Fetching the snapshot and installing ca-certificates in one command" && \
    apt install --update --snapshot "${SNAPSHOT}" -o Acquire::Check-Valid-Until=false -o Acquire::https::Verify-Peer=false -y ca-certificates && \
    : "Install dependencies" && \
    apt install --snapshot "${SNAPSHOT}" -y \
        crowdsec-firewall-bouncer \
        curl \
        iproute2 \
        kmod \
        isc-dhcp-client \
        nftables \
        openssh-server \
        procps \
        runit \
        wget

# kernel

COPY deps/linux-image.deb .

RUN dpkg -i linux-image.deb && rm linux-image.deb


# binaries

COPY --chmod=755 bin/certificate-issuer /usr/bin/certificate-issuer
COPY --chmod=755 bin/ic-gateway /usr/bin/ic-gateway
COPY --chmod=755 bin/vector /usr/bin/vector
COPY --chmod=755 bin/node_exporter /usr/bin/node_exporter


# vector config

COPY etc/vector /etc/vector


# firewall

COPY etc/crowdsec /etc/crowdsec
COPY etc/nftables.conf /etc/nftables.conf


# network tweaks
COPY etc/sysctl.d /etc/sysctl.d


# service definitions (runit)

COPY etc/sv /etc/sv

RUN \
  rm -r \
    /etc/sv/ssh \
    /etc/sv/svlogd


# init

COPY --chmod=755 init.sh /init


RUN \
  --mount=type=cache,target=/var/cache/apt,sharing=locked \
  --mount=type=cache,target=/var/lib/apt,sharing=locked \
    : "Clean up for improving reproducibility" && \
    rm -rf /var/log/* /var/cache/ldconfig/aux-cache
