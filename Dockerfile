# syntax=docker/dockerfile:1

FROM debian:trixie-20250929-slim

ENV DEBIAN_FRONTEND=noninteractive

# https://snapshot.debian.org/archive/debian/20250930T083630Z/
ARG SNAPSHOT=20250930T083630Z

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
  curl \
  iproute2 \
  kmod \
  nftables \
  openssh-server \
  procps \
  runit \
  ntpsec \
  wget \
  nano \
  tcpdump \
  vim

# kernel

COPY deps/linux-image.deb .
RUN dpkg -i linux-image.deb && rm linux-image.deb


# binaries

COPY --chmod=755 bin/ic-gateway /usr/bin/ic-gateway
COPY --chmod=755 bin/ic-http-lb /usr/bin/ic-http-lb
COPY --chmod=755 bin/vector /usr/bin/vector
COPY --chmod=755 bin/node_exporter /usr/bin/node_exporter


# crowdsec

RUN wget https://github.com/crowdsecurity/cs-firewall-bouncer/releases/download/v0.0.31/crowdsec-firewall-bouncer-linux-amd64.tgz && \
  echo "e4f6ed09fd9ce74117c2bc3db950326304cc741e1f6f532583d35b73a42dbad9  crowdsec-firewall-bouncer-linux-amd64.tgz" | shasum -c && \
  tar xzf crowdsec-firewall-bouncer-linux-amd64.tgz && \
  cp crowdsec-firewall-bouncer-v0.0.31/crowdsec-firewall-bouncer /usr/bin/crowdsec-firewall-bouncer


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

# misc
COPY etc/hosts /etc/hosts

# init

COPY --chmod=755 init.sh /init

RUN \
  --mount=type=cache,target=/var/cache/apt,sharing=locked \
  --mount=type=cache,target=/var/lib/apt,sharing=locked \
  : "Clean up for improving reproducibility" && \
  rm -rf /var/log/* /var/cache/ldconfig/aux-cache
