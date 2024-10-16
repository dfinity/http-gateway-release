#!/bin/bash

mount -t devtmpfs devtmpfs /dev
mount -t proc proc /proc
mount -t sysfs sysfs /sys

mnts=("/dev/sda /mnt")

# /mnt/ic-gateway   ic-gateway configuration and certificates
# /mnt/cert-issuer  certificate-issuer configuration
# /mnt/crowdsec     crowdsec credentials
# /mnt/nftables     nftables definitions
# /mnt/sshd         sshd authorized keys

# Configure network (local)
ip link set lo up

# Configure network (external)
ip link set eth0 up
dhclient -v -4
dhclient -v -6

# Configuration mounts
for v in "${mnts[@]}"; do
  IFS=' ' read -r dvc mnt <<< $v

  echo "Mounting $dvc at $mnt"
  mkdir -p $mnt && mount $dvc $mnt
done

# Configure firewall
nft -f /etc/nftables.conf

# Configure sysctl
sysctl -p /etc/sysctl.d/local.conf

# Start init
exec runsvdir -P /etc/sv
