#!/bin/bash

# Initialize Kubernetes master node
sudo kubeadm init --pod-network-cidr=10.69.0.0/16 --token $TOKEN

# Generate the hash for the CA certificate
openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt | \
openssl rsa -pubin -outform DER 2>/dev/null | \
sha256sum | \
awk '{print $1}' > hash

# Set up kubeconfig for the current user
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# Install Calico networking for the Kubernetes cluster
kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml

echo "Master node setup complete!"