#!/bin/bash

# Update and upgrade
sudo apt update && sudo apt upgrade -y

# Install dependencies
sudo apt install -y apt-transport-https ca-certificates curl gnupg lsb-release

# Disable swap (important for Kubernetes)
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab

# Install containerd
sudo apt install -y containerd
sudo mkdir -p /etc/containerd
sudo containerd config default | sudo tee /etc/containerd/config.toml
sudo systemctl restart containerd
sudo systemctl enable containerd

# Add Kubernetes apt repository
curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
echo "deb https://apt.kubernetes.io/ kubernetes-oracular main" | sudo tee /etc/apt/sources.list.d/kubernetes.list

# Update package index again after adding Kubernetes repo
sudo apt update

# Install Kubernetes packages (kubelet, kubeadm, kubectl)
sudo apt install -y kubelet kubeadm kubectl

# Mark packages to hold at their current version
sudo apt-mark hold kubelet kubeadm kubectl

# Install Calico networking for the Kubernetes cluster
kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml
