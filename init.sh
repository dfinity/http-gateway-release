#!/bin/bash

mount -t devtmpfs devtmpfs /dev
mount -t proc proc /proc
mount -t sysfs sysfs /sys

# Configure network
ip link set eth0 up
udhcpc -i eth0

# Configure firewall
nft -f /etc/nftables.conf

# Configure sysctl
sysctl -p /etc/sysctl.d/local.conf

mnts=(
  "/dev/sda /mnt/certs"       # ic-gateway certificates
  "/dev/sdb /mnt/cert-issuer" # certificate-issuer configuration
  "/dev/sdc /mnt/crowdsec"    # crowdsec credentials
)

# Configuration mounts
for v in "${mnts[@]}"; do
  IFS=' ' read -r dvc mnt <<< $v

  echo "Mounting $dvc at $mnt"
  mkdir $mnt && mount $dvc $mnt
done

# Start init
exec runsvdir -P /etc/service
