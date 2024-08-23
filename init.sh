#!/bin/sh

mount -t devtmpfs devtmpfs /dev
mount -t proc proc /proc
mount -t sysfs sysfs /sys

ip link set eth0 up
udhcpc -i eth0

mkdir /mnt/certs && mount /dev/sda /mnt/certs

/usr/bin/main \
    --log-stdout \
    --http-server-listen-plain '0.0.0.0:80' \
    --http-server-listen-tls '0.0.0.0:443' \
    --ic-url https://ic0.app \
    --domain icp5.io \
    --domain-canister-alias 'valid:qoctq-giaaa-aaaaa-aaaea-cai,invalid:qoctq-giaaa-aaaaa-aaaea-cai' \
    --cert-provider-dir /mnt/certs
