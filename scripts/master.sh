#!/bin/bash

# Ensure that TOKEN is set, otherwise exit
if [ -z "$TOKEN" ]; then
  echo "ERROR: TOKEN is not set. Exiting."
  exit 1
fi

# Enable IP forwarding for Kubernetes
echo "Enabling IP forwarding for Kubernetes..."
sudo sysctl net.ipv4.ip_forward=1
echo "net.ipv4.ip_forward = 1" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

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

# Check if the admin.conf file exists before copying
if [ -f /etc/kubernetes/admin.conf ]; then
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config
else
  echo "ERROR: /etc/kubernetes/admin.conf not found!"
  exit 1
fi

# Install Calico networking for the Kubernetes cluster
echo "Installing Calico networking for the cluster..."
kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml

echo "Master node setup complete!"