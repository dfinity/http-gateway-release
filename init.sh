#!/bin/sh

mount -t devtmpfs devtmpfs /dev
mount -t proc proc /proc
mount -t sysfs sysfs /sys

# Configure network
ip link set eth0 up
udhcpc -i eth0

# mount certificates for ic-gateway
mkdir /mnt/certs && mount /dev/sda /mnt/certs

# mount configuration for certificate-issuer
mkdir /mnt/cert-issuer && mount /dev/sdb /mnt/cert-issuer

# Start init
exec runsvdir -P /etc/service
