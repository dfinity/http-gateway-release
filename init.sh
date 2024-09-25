#!/bin/sh

mount -t devtmpfs devtmpfs /dev
mount -t proc proc /proc
mount -t sysfs sysfs /sys

# Configure network
ip link set eth0 up
udhcpc -i eth0

# Configure firewall
nft -f /etc/nftables.conf

# mount ic-gateway certificates
mkdir /mnt/certs && mount /dev/sda /mnt/certs

# mount certificate-issuer configuration
mkdir /mnt/cert-issuer && mount /dev/sdb /mnt/cert-issuer

# mount crowdsec configuration
mkdir /mnt/crowdsec && mount /dev/sdc /mnt/crowdsec

# Start init
exec runsvdir -P /etc/service
