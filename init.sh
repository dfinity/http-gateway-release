#!/bin/bash

mount -t devtmpfs devtmpfs /dev
mount -t proc proc /proc
mount -t sysfs sysfs /sys

mnts=(
  "/dev/sda /mnt/ic-gateway"  # ic-gateway configuration and certificates
  "/dev/sdb /mnt/cert-issuer" # certificate-issuer configuration
  "/dev/sdc /mnt/crowdsec"    # crowdsec credentials
  "/dev/sdd /mnt/nftables"    # nftables definitions
)

# Configure network (local)
ip link set lo up

# Configure network (external)
ip link set eth0 up
udhcpc -i eth0

# Configuration mounts
for v in "${mnts[@]}"; do
  IFS=' ' read -r dvc mnt <<< $v

  echo "Mounting $dvc at $mnt"
  mkdir $mnt && mount $dvc $mnt
done

# Configure firewall
nft -f /etc/nftables.conf

# Configure sysctl
sysctl -p /etc/sysctl.d/local.conf

# Start init
exec runsvdir -P /etc/service
