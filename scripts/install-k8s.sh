#!/bin/bash

# Ensure that ROLE is set, otherwise exit
if [ -z "$ROLE" ]; then
  echo "ERROR: ROLE is not set. Exiting."
  exit 1
fi

# Ensure that TOKEN is set (only for master node), otherwise exit
if [ "$ROLE" == "master" ] && [ -z "$TOKEN" ]; then
  echo "ERROR: TOKEN is not set. Exiting."
  exit 1
fi

# Update and upgrade the system
echo "Updating and upgrading system packages..."
sudo apt update && sudo apt upgrade -y

sleep 5

# Install necessary dependencies
echo "Installing dependencies..."
sudo apt install -y apt-transport-https ca-certificates curl gnupg lsb-release

sleep 5

# Disable swap (important for Kubernetes)
echo "Disabling swap..."
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab

# Install containerd
echo "Installing containerd..."
sudo apt install -y containerd
sudo mkdir -p /etc/containerd
sudo containerd config default | sudo tee /etc/containerd/config.toml
sudo systemctl restart containerd
sudo systemctl enable containerd

sleep 5

# Add Kubernetes apt repository
echo "Adding Kubernetes APT repository..."
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt update

sleep 5

# Install Kubernetes components
echo "Installing Kubernetes components..."
sudo apt install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl
sudo systemctl enable --now kubelet

# Enable IP forwarding for Kubernetes
echo "Enabling IP forwarding..."
sudo sysctl -w net.ipv4.ip_forward=1
sudo sysctl -w net.bridge.bridge-nf-call-iptables=1
echo "net.ipv4.ip_forward = 1" | sudo tee -a /etc/sysctl.conf
echo "net.bridge.bridge-nf-call-iptables = 1" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

modprobe br_netfilter
sysctl -w net.bridge.bridge-nf-call-iptables=1

sleep 5

echo "y" | sudo ufw enable 
# system
sudo ufw allow 22
sudo ufw allow 179
# http
sudo ufw allow 80
sudo ufw allow 443
# k8s
sudo ufw allow 6443
sudo ufw allow 2379
sudo ufw allow 2380
sudo ufw allow 10250
sudo ufw allow 10259
sudo ufw allow 10256
sudo ufw allow 10257
sudo ufw allow 30000:32767/tcp
# flannel
sudo ufw allow 8472
# metallb
sudo ufw allow 7946
sudo ufw allow 7472

# If running on the master node, perform master-specific setup
if [ "$ROLE" == "master" ]; then
  echo "Configuring master node..."

  # --- CLEANUP STEPS ADDED HERE ---
  echo "--- Cleaning up previous Kubernetes installation ---"
  kubeadm reset -f 2>&1 | tee kubeadm-reset.log # Reset kubeadm and log output
  if [ $? -ne 0 ]; then
    echo "kubeadm reset failed. Please check kubeadm-reset.log for errors. Exiting."
    cat kubeadm-reset.log || true
    exit 1
  fi
  sudo rm -rf /var/lib/etcd # Remove etcd data directory
  # --- CLEANUP STEPS END ---

  # --- DIAGNOSTIC STEP: crictl pods BEFORE kubeadm init ---
  echo "--- crictl pods BEFORE kubeadm init ---"
  sudo crictl pods --namespace kube-system

  # Initialize Kubernetes master node with the provided token - INCREASED VERBOSITY
  echo "Initializing Kubernetes master node..."
  kubeadm init --pod-network-cidr=10.244.0.0/16 --token $TOKEN --v=6 2>&1 | tee kubeadm-init.log

  # --- DIAGNOSTIC STEP: crictl pods AFTER kubeadm init, BEFORE readiness check ---
  echo "--- crictl pods AFTER kubeadm init, BEFORE readiness check ---"
  sudo crictl pods --namespace kube-system

  echo "--- Pausing for 15 seconds after kubeadm init to allow pod logging ---"
  sleep 15

  if [ $? -ne 0 ]; then
    echo "kubeadm init failed. Exiting."
    exit 1
  fi

  echo "Waiting for Kubernetes API to be ready..."
  until kubectl cluster-info; do
    echo "Waiting for API server..."
    sleep 5
  done

  echo "Setting up kubeconfig for users..."
  for user in root k8s; do
    USER_HOME=$(eval echo ~$user)
    mkdir -p $USER_HOME/.kube
    sudo cp -i /etc/kubernetes/admin.conf $USER_HOME/.kube/config
    sudo chown $user:$user $USER_HOME/.kube/config
    sudo chmod 600 $USER_HOME/.kube/config
  done

  echo "Installing Flannel networking for the cluster..."
  if ! kubectl get daemonset -n kube-system | grep -q flannel; then
    kubectl apply -f https://github.com/coreos/flannel/raw/master/Documentation/kube-flannel.yml
  fi

  echo "Generating the hash for the CA certificate..."
  openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt | \
  openssl rsa -pubin -outform DER 2>/dev/null | \
  sha256sum | \
  awk '{print $1}' > hash

  echo "Master node setup complete!"
else
  echo "Configuring worker node..."

  if [ $# -ne 3 ]; then
    echo "ERROR: Missing arguments for worker setup. Usage: $0 <master-ip> <token> <hash>"
    exit 1
  fi

  MASTER_IP=$1
  TOKEN=$2
  HASH=$3

  echo "Joining the worker node to the cluster..."
  sudo kubeadm join ${MASTER_IP}:6443 --token ${TOKEN} \
      --discovery-token-ca-cert-hash sha256:${HASH}

  echo "Worker node successfully joined the cluster!"
fi
