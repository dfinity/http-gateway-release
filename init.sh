#!/bin/bash

mount -t devtmpfs devtmpfs /dev
mkdir /dev/pts && mount -t devpts devpts /dev/pts
mount -t proc proc /proc
mount -t sysfs sysfs /sys

mnts=("/dev/sda /mnt")

# /mnt/cert-issuer  certificate-issuer configuration
# /mnt/crowdsec     crowdsec credentials
# /mnt/ic-gateway   ic-gateway configuration and certificates
# /mnt/networking   networking configuration
# /mnt/nftables     nftables definitions
# /mnt/sshd         sshd authorized keys

# Configure network (local)
ip link set lo up

# Configure network (external)
ip link set eth0 up

# Configuration mounts
for v in "${mnts[@]}"; do
  IFS=' ' read -r dvc mnt <<< $v

  echo "Mounting $dvc at $mnt"
  mkdir -p $mnt && mount $dvc $mnt
done

# Set hostname if any
if [ -f /mnt/hostname ]; then
  hostname -F /mnt/hostname
  HOSTNAME=$(cat /mnt/hostname)
  echo "127.0.0.1 ${HOSTNAME}" >> /etc/hosts
fi

# Configure firewall
nft -f /etc/nftables.conf

# Configure sysctl
sysctl -p /etc/sysctl.d/local.conf

# Configure networking (IPv4)
if [ -f /mnt/networking/ipv4.conf ]; then
  echo "Configuring IPv4"
  while IFS=' ' read -r key value; do
    case "$key" in
      ipv4_address)
        echo "Configuring IP address: $value"
        ip address add $value dev eth0
        ;;

      ipv4_gateway)
        echo "Configuring gateway: $value"
        ip route add default via $value dev eth0
        ;;

      *)
        echo "Unknown configuration: $key"
        ;;
    esac
  done < /mnt/networking/ipv4.conf
fi

# Configure networking (IPv6)
if [ -f /mnt/networking/ipv6.conf ]; then
  echo "Configuring IPv6"
  while IFS=' ' read -r key value; do
    case "$key" in
      ipv6_address)
        echo "Configuring IP address: $value"
        ip -6 address add $value dev eth0
        ;;

      ipv6_gateway)
        echo "Configuring gateway: $value"
        ip -6 route add default via $value dev eth0
        ;;

      *)
        echo "Unknown configuration: $key"
        ;;
    esac
  done < /mnt/networking/ipv6.conf
else
  echo "No IPv6 configuration found. IPv6 is configured automatically via SLAAC"
fi

ip a

# Start init
exec runsvdir -P /etc/sv
