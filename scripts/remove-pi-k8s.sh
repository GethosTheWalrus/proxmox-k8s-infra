#!/bin/bash
set -e

# This script removes Kubernetes from a Raspberry Pi node.
# Run as root: sudo bash -s < remove-pi-k8s.sh

export DEBIAN_FRONTEND=noninteractive

echo "Removing Kubernetes from $(hostname)..."

# Reset kubeadm
if command -v kubeadm &>/dev/null; then
  echo "Resetting kubeadm..."
  kubeadm reset -f || true
fi

# Stop kubelet
systemctl stop kubelet 2>/dev/null || true
systemctl disable kubelet 2>/dev/null || true

# Remove Kubernetes packages
echo "Removing Kubernetes packages..."
apt-mark unhold kubelet kubeadm kubectl 2>/dev/null || true
apt-get purge -y kubelet kubeadm kubectl 2>/dev/null || true
apt-get autoremove -y

# Clean up directories
echo "Cleaning up Kubernetes directories..."
rm -rf /etc/cni/net.d
rm -rf /var/lib/kubelet
rm -rf /var/lib/etcd
rm -rf /etc/kubernetes
rm -rf /root/.kube
rm -f /etc/apt/sources.list.d/kubernetes.list
rm -f /etc/apt/keyrings/kubernetes-apt-keyring.gpg
rm -f /etc/sysctl.d/k8s.conf
rm -f /etc/modules-load.d/k8s.conf

# Clean up containerd registry config
rm -rf /etc/containerd/certs.d

# Restore default containerd config without custom registry paths
if [ -f /etc/containerd/config.toml ]; then
  sed -i 's|config_path = "/etc/containerd/certs.d"|config_path = ""|' /etc/containerd/config.toml
  systemctl restart containerd 2>/dev/null || true
fi

# Reset iptables rules added by Kubernetes
echo "Resetting iptables rules..."
iptables -F && iptables -t nat -F && iptables -t mangle -F && iptables -X 2>/dev/null || true
ip6tables -F && ip6tables -t nat -F && ip6tables -t mangle -F && ip6tables -X 2>/dev/null || true

echo "Kubernetes cleanup complete on $(hostname)"
