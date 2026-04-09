#!/bin/bash
set -e

# This script runs on a Raspberry Pi node to install Kubernetes
# and join an existing cluster as a worker or control-plane node.
# Usage: sudo bash -s < install-pi-k8s.sh <master-ip> <join-token> <ca-cert-hash> [control-plane <cert-key>]

MASTER_IP=$1
TOKEN=$2
HASH=$3
ROLE=${4:-worker}
CERT_KEY=$5

if [ -z "$MASTER_IP" ] || [ -z "$TOKEN" ] || [ -z "$HASH" ]; then
  echo "ERROR: Usage: $0 <master-ip> <join-token> <ca-cert-hash> [control-plane <cert-key>]"
  exit 1
fi

if [ "$ROLE" = "control-plane" ] && [ -z "$CERT_KEY" ]; then
  echo "ERROR: CERT_KEY is required when joining as control-plane"
  exit 1
fi

echo "Joining cluster as: $ROLE"

export DEBIAN_FRONTEND=noninteractive

# Check if memory cgroup is available at runtime
CGROUP_MEMORY_OK=false
if [ -f /sys/fs/cgroup/cgroup.controllers ]; then
  echo "cgroup v2 detected. Controllers: $(cat /sys/fs/cgroup/cgroup.controllers)"
  grep -q memory /sys/fs/cgroup/cgroup.controllers && CGROUP_MEMORY_OK=true
elif [ -e /sys/fs/cgroup/memory ]; then
  echo "cgroup v1 memory controller detected"
  CGROUP_MEMORY_OK=true
fi

if [ "$CGROUP_MEMORY_OK" = "false" ]; then
  echo "WARNING: Memory cgroup not available at runtime!"
  echo "Kernel cmdline: $(cat /proc/cmdline)"

  # Find and update boot cmdline
  CMDLINE_FILE=""
  for f in /boot/firmware/cmdline.txt /boot/cmdline.txt; do
    if [ -f "$f" ]; then
      CMDLINE_FILE="$f"
      break
    fi
  done

  if [ -n "$CMDLINE_FILE" ]; then
    echo "Boot cmdline file ($CMDLINE_FILE): $(cat "$CMDLINE_FILE")"
    if ! grep -q "cgroup_enable=memory" "$CMDLINE_FILE"; then
      echo "Adding cgroup boot parameters..."
      sed -i 's/$/ cgroup_memory=1 cgroup_enable=memory/' "$CMDLINE_FILE"
      echo "Updated cmdline: $(cat "$CMDLINE_FILE")"
    else
      echo "Boot params already present but not active. Rebooting to apply..."
    fi
    echo "Rebooting to enable memory cgroup..."
    nohup bash -c "sleep 2 && reboot" &>/dev/null &
    exit 100
  else
    echo "ERROR: No cmdline.txt found. Cannot enable memory cgroup."
    echo "Contents of /boot/: $(ls /boot/)"
    echo "Contents of /boot/firmware/: $(ls /boot/firmware/ 2>/dev/null || echo 'not found')"
    exit 1
  fi
else
  echo "Memory cgroup is available"
fi

# Skip if already joined to a cluster
if systemctl is-active --quiet kubelet && [ -f /etc/kubernetes/kubelet.conf ]; then
  echo "Node $(hostname) is already part of a cluster. Skipping join."
  exit 0
fi

# Reset if previously partially installed (kubeadm present but kubelet not running)
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

# Ensure hostname resolves locally
HOSTNAME=$(hostname)
if ! getent hosts "$HOSTNAME" &>/dev/null; then
  echo "Adding $HOSTNAME to /etc/hosts..."
  LOCAL_IP=$(ip -4 route get 1 | awk '{print $7; exit}')
  echo "$LOCAL_IP $HOSTNAME" >> /etc/hosts
fi

# Disable swap (including zram)
echo "Disabling swap..."
swapoff -a 2>/dev/null || true
# Remove systemd-zram-generator which auto-creates zram swap at boot
if dpkg -l | grep -q systemd-zram-generator; then
  echo "Removing systemd-zram-generator package..."
  apt-get remove -y systemd-zram-generator 2>/dev/null || true
fi
swapoff /dev/zram0 2>/dev/null || true
zramctl --reset /dev/zram0 2>/dev/null || true
modprobe -r zram 2>/dev/null || true
# Also disable dphys-swapfile if present
if systemctl list-units --type=service --all | grep -q dphys-swapfile; then
  systemctl disable --now dphys-swapfile 2>/dev/null || true
fi
sed -i '/ swap / s/^/#/' /etc/fstab
echo "Swap status after disable: $(free -h | grep Swap)"

# Prevent IPv6 Router Advertisements from adding DNS servers
# ISP routers may advertise IPv6 DNS via RDNSS, pushing the nameserver count
# above Linux's 3-entry limit, causing Kubernetes DNSConfigForming warnings
echo "Disabling IPv6 RA DNS..."
if command -v nmcli &>/dev/null; then
  for conn in $(nmcli -t -f NAME con show --active); do
    echo "Setting ipv6.ignore-auto-dns on connection: $conn"
    nmcli con mod "$conn" ipv6.ignore-auto-dns yes 2>/dev/null || true
  done
  nmcli general reload 2>/dev/null || true
  # Reapply active connections to pick up changes
  for conn in $(nmcli -t -f NAME con show --active); do
    nmcli con up "$conn" 2>/dev/null || true
  done
fi

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

# Ensure hostname resolves locally
HOSTNAME=$(hostname)
if ! getent hosts "$HOSTNAME" &>/dev/null; then
  echo "Adding $HOSTNAME to /etc/hosts..."
  LOCAL_IP=$(ip -4 route get 1 | awk '{print $7; exit}')
  echo "$LOCAL_IP $HOSTNAME" >> /etc/hosts
fi

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
  if [ "$ROLE" = "control-plane" ]; then
    # Additional ports for control-plane nodes
    ufw allow 2379  # etcd client
    ufw allow 2380  # etcd peer
    ufw allow 10259 # kube-scheduler
    ufw allow 10257 # kube-controller-manager
  fi
fi

# Fix resolv.conf for kubelet — Raspberry Pi OS may not have the systemd-resolved
# symlink that kubelet expects at /run/systemd/resolve/resolv.conf
if [ ! -e /run/systemd/resolve/resolv.conf ]; then
  echo "Creating resolv.conf symlink for kubelet..."
  mkdir -p /run/systemd/resolve
  ln -sf /etc/resolv.conf /run/systemd/resolve/resolv.conf
  # Persist across reboots via tmpfiles.d
  cat <<EOF | tee /etc/tmpfiles.d/resolv-compat.conf
L /run/systemd/resolve/resolv.conf - - - - /etc/resolv.conf
EOF
  systemd-tmpfiles --create 2>/dev/null || true
fi

# Fix CNI binary path — kubelet/flannel expects binaries in /opt/cni/bin
# but Debian Trixie installs them to /usr/lib/cni
if [ -d /usr/lib/cni ] && [ ! -d /opt/cni/bin ] || [ -z "$(ls -A /opt/cni/bin 2>/dev/null)" ]; then
  echo "Creating CNI symlinks from /usr/lib/cni to /opt/cni/bin..."
  mkdir -p /opt/cni/bin
  for bin in /usr/lib/cni/*; do
    [ -f "$bin" ] && ln -sf "$bin" /opt/cni/bin/
  done
elif [ -d /opt/cni/bin ] && [ -d /usr/lib/cni ]; then
  # Ensure reverse symlinks exist too for any tools checking /usr/lib/cni
  for bin in /opt/cni/bin/*; do
    [ -f "$bin" ] && [ ! -e "/usr/lib/cni/$(basename "$bin")" ] && ln -sf "$bin" /usr/lib/cni/
  done
fi

# Join the cluster
if [ "$ROLE" = "control-plane" ]; then
  echo "Joining the Kubernetes cluster as CONTROL PLANE at ${MASTER_IP}:6443..."
  kubeadm join ${MASTER_IP}:6443 --token ${TOKEN} --discovery-token-ca-cert-hash sha256:${HASH} \
    --control-plane --certificate-key ${CERT_KEY}

  # Set up kubeconfig for the new control-plane node
  echo "Setting up kubeconfig..."
  USER_HOME=$(eval echo ~${SUDO_USER})
  KUBE_USER=${SUDO_USER:-$(whoami)}
  mkdir -p "$USER_HOME/.kube"
  cp -f /etc/kubernetes/admin.conf "$USER_HOME/.kube/config"
  chown "$KUBE_USER:$KUBE_USER" "$USER_HOME/.kube/config"
  chmod 600 "$USER_HOME/.kube/config"
else
  echo "Joining the Kubernetes cluster as WORKER at ${MASTER_IP}:6443..."
  kubeadm join ${MASTER_IP}:6443 --token ${TOKEN} --discovery-token-ca-cert-hash sha256:${HASH}
fi

echo "Successfully joined the cluster as $ROLE! Node: $(hostname)"
