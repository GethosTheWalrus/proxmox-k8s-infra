#!/bin/bash

# Ensure the script takes three arguments: master IP, token, and hash
if [ $# -ne 3 ]; then
  echo "Usage: $0 <master-ip> <token> <hash>"
  exit 1
fi

# Assign the arguments to variables
MASTER_IP=$1
TOKEN=$2
HASH=$3

# Run the kubeadm join command with the provided token and hash
sudo kubeadm join ${MASTER_IP}:6443 --token ${TOKEN} \
    --discovery-token-ca-cert-hash sha256:${HASH}

echo "Worker node successfully joined the cluster!"