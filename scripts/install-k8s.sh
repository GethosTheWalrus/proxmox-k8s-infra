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

# Enable SystemdCgroup for containerd (required for kubeadm)
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

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
sudo sysctl net.ipv4.ip_forward=1
sudo sysctl net.bridge.bridge-nf-call-iptables = 1
echo "net.ipv4.ip_forward = 1" | sudo tee -a /etc/sysctl.conf
echo "net.bridge.bridge-nf-call-iptables = 1" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

modprobe br_netfilter
echo 'br_netfilter' | sudo tee -a /etc/modules-load.d/k8s.conf
sysctl -w net.bridge.bridge-nf-call-iptables = 1

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

  # --- PAUSE AFTER kubeadm init ---
  echo "--- Pausing for 15 seconds after kubeadm init to allow pod logging ---"
  sleep 15

  # --- DIAGNOSTIC: Dump admin.conf content AFTER kubeadm init, BEFORE readiness check ---
  echo "--- Dumping /etc/kubernetes/admin.conf content AFTER kubeadm init, BEFORE readiness check ---"
  sudo cat /etc/kubernetes/admin.conf || true

  # Check if kubeadm init was successful
  if [ $? -ne 0 ]; then
    echo "kubeadm init failed. Exiting."
    exit 1
  fi

  # Set up kubeconfig for the non-root user
  echo "Setting up kubeconfig for the non-root user..."
  USER_HOME=$(eval echo ~${SUDO_USER})
  mkdir -p /home/k8s/.kube
  sudo cp -i /etc/kubernetes/admin.conf /home/k8s/.kube/config
  sudo chown k8s:k8s /home/k8s/.kube/config
  sudo chmod 600 /home/k8s/.kube/config

  # Also make kubectl accessible for root (optional)
  mkdir -p /root/.kube
  cp -i /etc/kubernetes/admin.conf /root/.kube/config
  chown root:root /root/.kube/config
  chmod 600 /root/.kube/config
  
  export KUBECONFIG=/root/.kube/config

  # Wait for the Kubernetes API to be up and running
  echo "Waiting for Kubernetes API to be ready..."

  API_READY=false
  RETRY_COUNT=0
  MAX_RETRIES=60
  while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    RETRY_COUNT=$((RETRY_COUNT + 1))
    echo "kubectl cluster-info attempt - Retry: $RETRY_COUNT/$MAX_RETRIES - Time: $(date +%Y-%m-%d_%H:%M:%S)"

    # Get kubectl cluster-info AND status INSIDE the loop
    KUBECTL_OUTPUT=$(kubectl cluster-info 2>&1)
    API_SERVER_STATUS=$?

    if [ "$API_SERVER_STATUS" -eq 0 ]; then
      API_READY=true
      echo "Kubernetes API server is ready!"
      break
    else
      echo "Kubernetes API server not yet ready. Waiting... (Retry: $RETRY_COUNT/$MAX_RETRIES)"
      echo "kubectl cluster-info output (Retry: $RETRY_COUNT):"
      echo "$KUBECTL_OUTPUT"
    fi
    sleep 5
  done
  
  if [ "$API_READY" != "true" ]; then
    echo "Kubernetes API server failed to become ready after $MAX_RETRIES attempts. Exiting."
    exit 1
  fi

  # Install Flannel networking for the Kubernetes cluster
  echo "Installing Flannel networking for the cluster..."
  kubectl apply -f https://github.com/coreos/flannel/raw/master/Documentation/kube-flannel.yml

  # Generate the hash for the CA certificate
  echo "Generating the hash for the CA certificate..."
  openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt | \
  openssl rsa -pubin -outform DER 2>/dev/null | \
  sha256sum | \
  awk '{print $1}' > hash

  echo "Master node setup complete!"
else
  echo "Configuring worker node..."

  # Ensure that the correct arguments are passed for worker node setup
  if [ $# -ne 3 ]; then
    echo "ERROR: Missing arguments for worker setup. Usage: $0 <master-ip> <token> <hash>"
    exit 1
  fi

  MASTER_IP=$1
  TOKEN=$2
  HASH=$3

  # Join the worker node to the Kubernetes cluster
  echo "Joining the worker node to the cluster..."
  sudo kubeadm join ${MASTER_IP}:6443 --token ${TOKEN} \
      --discovery-token-ca-cert-hash sha256:${HASH}

  echo "Worker node successfully joined the cluster!"
fi