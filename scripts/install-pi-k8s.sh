#!/bin/bash
set -e

# This script runs on a Raspberry Pi node to install Kubernetes
# and join an existing cluster as a worker.
# Usage: sudo bash -s < install-pi-k8s.sh <master-ip> <join-token> <ca-cert-hash>

MASTER_IP=$1
TOKEN=$2
HASH=$3

if [ -z "$MASTER_IP" ] || [ -z "$TOKEN" ] || [ -z "$HASH" ]; then
  echo "ERROR: Usage: $0 <master-ip> <join-token> <ca-cert-hash>"
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive

# Enable cgroups for Raspberry Pi if needed (requires reboot before anything else)
if [ -f /boot/firmware/cmdline.txt ] || [ -f /boot/cmdline.txt ]; then
  CMDLINE_FILE="/boot/firmware/cmdline.txt"
  [ ! -f "$CMDLINE_FILE" ] && CMDLINE_FILE="/boot/cmdline.txt"
  if [ -f "$CMDLINE_FILE" ] && ! grep -q "cgroup_memory=1" "$CMDLINE_FILE"; then
    echo "Enabling cgroup memory on Raspberry Pi..."
    sed -i 's/$/ cgroup_memory=1 cgroup_enable=memory/' "$CMDLINE_FILE"
    echo "Rebooting to apply cgroup settings..."
    nohup bash -c "sleep 2 && reboot" &>/dev/null &
    exit 100
  fi
fi

# Reset if previously joined to a cluster
if command -v kubeadm &>/dev/null; then
  echo "Resetting previous Kubernetes installation..."
  kubeadm reset -f || true
  rm -rf /etc/cni/net.d /var/lib/kubelet/*
fi

# Update system
echo "Updating system packages..."
apt-get update && apt-get upgrade -y

sleep 5

# Install dependencies
echo "Installing dependencies..."
apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release

sleep 5

# Disable swap
echo "Disabling swap..."
swapoff -a
sed -i '/ swap / s/^/#/' /etc/fstab

# Install containerd
echo "Installing containerd..."
apt-get install -y containerd
mkdir -p /etc/containerd
containerd config default | tee /etc/containerd/config.toml > /dev/null

# Enable SystemdCgroup
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

# Configure containerd for HTTP registry at git.home:5050
mkdir -p /etc/containerd/certs.d/git.home:5050
cat <<EOF | tee /etc/containerd/certs.d/git.home:5050/hosts.toml
server = "http://git.home:5050"

[host."http://git.home:5050"]
  capabilities = ["pull", "resolve"]
  skip_verify = true
EOF

sed -i 's|config_path = ""|config_path = "/etc/containerd/certs.d"|' /etc/containerd/config.toml

systemctl restart containerd
systemctl enable containerd

sleep 5

# Add Kubernetes apt repository
echo "Adding Kubernetes APT repository..."
mkdir -p /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key | gpg --dearmor --yes -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /' | tee /etc/apt/sources.list.d/kubernetes.list
apt-get update

sleep 5

# Install Kubernetes components
echo "Installing Kubernetes components..."
apt-get install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl
systemctl enable --now kubelet

# Enable IP forwarding and bridge netfilter
echo "Enabling IP forwarding..."
modprobe br_netfilter
echo 'br_netfilter' | tee /etc/modules-load.d/k8s.conf

cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
sysctl --system

sleep 5

# Configure firewall if ufw is available
if command -v ufw &>/dev/null; then
  echo "y" | ufw enable
  ufw allow 22
  ufw allow 179
  ufw allow 80
  ufw allow 443
  ufw allow 6443
  ufw allow 10250
  ufw allow 30000:32767/tcp
  ufw allow 8472
  ufw allow 7946
  ufw allow 7472
fi

# Join the cluster
echo "Joining the Kubernetes cluster at ${MASTER_IP}:6443..."
kubeadm join ${MASTER_IP}:6443 --token ${TOKEN} --discovery-token-ca-cert-hash sha256:${HASH}

echo "Successfully joined the cluster! Node: $(hostname)"
