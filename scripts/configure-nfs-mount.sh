#!/bin/bash
set -euo pipefail

NFS_SERVER=${NFS_SERVER:-192.168.69.17}
NFS_PATH=${NFS_PATH:-/volume1/K8s}
NFS_MOUNT=${NFS_MOUNT:-/mnt/k8s-nfs}
FSTAB_ENTRY="${NFS_SERVER}:${NFS_PATH} ${NFS_MOUNT} nfs defaults,_netdev,nofail 0 0"

export DEBIAN_FRONTEND=noninteractive

echo "Installing NFS client package..."
if command -v apt-get &>/dev/null; then
  apt-get update
  apt-get install -y nfs-common
else
  echo "ERROR: apt-get is required to install nfs-common."
  exit 1
fi

echo "Configuring persistent NFS mount: ${NFS_SERVER}:${NFS_PATH} -> ${NFS_MOUNT}"
mkdir -p "$NFS_MOUNT"

if grep -qsE "^[^#]+[[:space:]]+${NFS_MOUNT//\//\/}[[:space:]]+" /etc/fstab; then
  sed -i "s|^[^#]*[[:space:]]${NFS_MOUNT//\//\/}[[:space:]].*|${FSTAB_ENTRY}|" /etc/fstab
elif ! grep -qsF "$FSTAB_ENTRY" /etc/fstab; then
  printf '\n%s\n' "$FSTAB_ENTRY" >> /etc/fstab
fi

systemctl daemon-reload 2>/dev/null || true
mount "$NFS_MOUNT" || mount -a

echo "NFS mount ready. Contents:"
ls -la "$NFS_MOUNT"
