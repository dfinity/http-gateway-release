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
        curl \
        iproute2 \
        kmod \
        udhcpc \
        wget


# kernel

COPY linux-image.deb .

RUN dpkg -i linux-image.deb && rm linux-image.deb


# binaries

COPY --chmod=755 ic-gateway /usr/bin/main


# init

COPY --chmod=755 init.sh /init


RUN \
  --mount=type=cache,target=/var/cache/apt,sharing=locked \
  --mount=type=cache,target=/var/lib/apt,sharing=locked \
    : "Clean up for improving reproducibility (optional)" && \
    rm -rf /var/log/* /var/cache/ldconfig/aux-cache
