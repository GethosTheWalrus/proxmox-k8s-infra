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

# Install necessary dependencies
echo "Installing dependencies..."
sudo apt install -y apt-transport-https ca-certificates curl gnupg lsb-release

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

# Add Kubernetes apt repository
echo "Adding Kubernetes APT repository..."
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update

# Install Kubernetes components
echo "Installing Kubernetes components..."
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl
sudo systemctl enable --now kubelet

# Enable IP forwarding for Kubernetes
echo "Enabling IP forwarding..."
sudo sysctl net.ipv4.ip_forward=1
echo "net.ipv4.ip_forward = 1" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

# If running on the master node, perform master-specific setup
if [ "$ROLE" == "master" ]; then
  echo "Configuring master node..."

  # Initialize Kubernetes master node with the provided token
  echo "Initializing Kubernetes master node..."
  sudo kubeadm init --pod-network-cidr=10.69.0.0/16 --token $TOKEN

  # Check if kubeadm init was successful
  if [ $? -ne 0 ]; then
    echo "kubeadm init failed. Exiting."
    exit 1
  fi

  # Wait for the Kubernetes API to be up and running
  echo "Waiting for Kubernetes API to be up..."
  sleep 30  # This can be adjusted based on your environment (waiting for kubelet to initialize)

  # Generate the hash for the CA certificate
  echo "Generating the hash for the CA certificate..."
  openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt | \
  openssl rsa -pubin -outform DER 2>/dev/null | \
  sha256sum | \
  awk '{print $1}' > hash

  # Set up kubeconfig for the current user
  echo "Setting up kubeconfig for the current user..."
  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config

  # Install Calico networking for the Kubernetes cluster
  echo "Installing Calico networking for the cluster..."
  kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml

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
