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

  # --- CLEANUP STEPS ADDED HERE ---
  echo "--- Cleaning up previous Kubernetes installation ---"
  sudo kubeadm reset -f 2>&1 | tee kubeadm-reset.log # Reset kubeadm and log output
  if [ $? -ne 0 ]; then
    echo "kubeadm reset failed. Please check kubeadm-reset.log for errors. Exiting."
    cat kubeadm-reset.log || true
    exit 1
  fi
  sudo rm -rf /var/lib/etcd # Remove etcd data directory
  # --- CLEANUP STEPS END ---

  # Install Calico networking for the Kubernetes cluster
  echo "Installing Calico networking for the cluster..."
  sudo -u $SUDO_USER kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml

  # --- DIAGNOSTIC STEP: crictl pods BEFORE kubeadm init ---
  echo "--- crictl pods BEFORE kubeadm init ---"
  sudo crictl pods --namespace kube-system

  # Initialize Kubernetes master node with the provided token - INCREASED VERBOSITY
  echo "Initializing Kubernetes master node..."
  sudo kubeadm init --pod-network-cidr=10.69.0.0/16 --token $TOKEN --v=6 2>&1 | tee kubeadm-init.log # Redirect kubeadm init output to log file, VERBOSITY INCREASED

  # --- DIAGNOSTIC STEP: crictl pods AFTER kubeadm init, BEFORE readiness check ---
  echo "--- crictl pods AFTER kubeadm init, BEFORE readiness check ---"
  sudo crictl pods --namespace kube-system

  # --- PAUSE AFTER kubeadm init ---
  echo "--- Pausing for 15 seconds after kubeadm init to allow pod logging ---"
  sleep 15

  # Check if kubeadm init was successful
  if [ $? -ne 0 ]; then
    echo "kubeadm init failed. Exiting."
    exit 1
  fi

  # Wait for the Kubernetes API to be up and running - Improved Readiness Check with Loop Debugging
  echo "Waiting for Kubernetes API to be ready... (Readiness Check Block Started)"  # START MARKER

  API_READY=false
  RETRY_COUNT=0 # Initialize retry counter
  while true; do
    RETRY_COUNT=$((RETRY_COUNT + 1))
    echo "kubectl cluster-info attempt - Retry: $RETRY_COUNT - Time: $(date +%Y-%m-%d_%H:%M:%S)" # Debug message with retry count

    # --- DIAGNOSTIC: Explicitly use kubeconfig and log output ---
    KUBECTL_OUTPUT=$(kubectl cluster-info --kubeconfig /etc/kubernetes/admin.conf 2>&1) # Explicit kubeconfig
    API_SERVER_STATUS=$?

    echo "kubectl cluster-info attempt - Status Code: $API_SERVER_STATUS - Retry: $RETRY_COUNT - Time: $(date +%Y-%m-%d_%H:%M:%S)" # Echo status code again

    if [ "$API_SERVER_STATUS" -eq 0 ]; then
      API_READY=true
      break
    else
      echo "Kubernetes API server not yet ready. Waiting... (Retry: $RETRY_COUNT)"
      echo "kubectl cluster-info output (Retry: $RETRY_COUNT):" # Print captured output if not ready
      echo "$KUBECTL_OUTPUT"
    fi
    sleep 5
  done
  if [ "$API_READY" == false ]; then
    echo "ERROR: Kubernetes API server did not become ready after waiting. Deeper diagnostics:"

    echo "--- Dumping kubeadm init logs (again) ---" # Re-dump kubeadm init logs
    cat kubeadm-init.log || true
    echo "--- Dumping kubeadm reset logs ---" # Dump kubeadm reset logs
    cat kubeadm-reset.log || true

    # --- DIAGNOSTIC: Dump admin.conf content ---
    echo "--- Dumping /etc/kubernetes/admin.conf content ---"
    sudo cat /etc/kubernetes/admin.conf || true

    echo "--- Getting kubelet status (again) ---" # Re-get kubelet status
    sudo systemctl status kubelet

    echo "--- Getting kubelet logs (again, last 100 lines) ---" # More kubelet logs
    sudo journalctl -u kubelet -n 100 --no-pager

    echo "--- Getting containerd status (again) ---" # Re-get containerd status
    sudo systemctl status containerd

    echo "--- Getting containerd logs (again, last 100 lines) ---" # More containerd logs
    sudo journalctl -u containerd -n 100 --no-pager

    # --- DIAGNOSTIC STEP: crictl pods in ERROR BLOCK (IMMEDIATELY AFTER READINESS FAILURE) ---
    echo "--- crictl pods in ERROR BLOCK (after readiness failure) ---"
    sudo crictl pods --namespace kube-system

    echo "--- Getting logs of kube-apiserver pod (if running) using crictl ---" # NEW: Get apiserver logs (if pod exists)
    API_SERVER_POD_ID=$(sudo crictl pods --namespace kube-system -o json | jq -r '.items[] | select(.metadata.name | contains("kube-apiserver")) | .id')
    if [ -n "$API_SERVER_POD_ID" ]; then
      echo "Found kube-apiserver pod ID: $API_SERVER_POD_ID. Dumping logs..."
      sudo crictl logs $API_SERVER_POD_ID
    else
      echo "kube-apiserver pod ID not found. Pod may have failed to start or has already terminated."
    fi

    echo "--- Checking system resource usage (CPU, Memory, Disk) ---" # NEW: Resource usage check
    uptime
    free -m
    df -h

    exit 1
  fi
  echo "Kubernetes API server is ready!"

  # Verify Calico pods are running - ADDED
  echo "Verifying Calico pods are running..."
  CALICO_READY=false
  while true; do
    calico_pods_ready=$(sudo -u $SUDO_USER kubectl get pods -n calico-system -l k8s-app=calico-node -o go-template='{{range .items}}{{.status.phase}}{{"\n"}}{{end}}' | grep Running | wc -l)
    if [ "$calico_pods_ready" -eq 3 ]; then # Assuming 3 nodes in your cluster, adjust if needed
      CALICO_READY=true
      break
    fi
    echo "Waiting for Calico pods to become ready..."
    sleep 10
  done
  if [ "$CALICO_READY" == false ]; then
    echo "ERROR: Calico pods did not become ready. Check Calico installation logs."
    exit 1
  fi
  echo "Calico network installation verified!"


  # Generate the hash for the CA certificate
  echo "Generating the hash for the CA certificate..."
  openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt | \
  openssl rsa -pubin -outform DER 2>/dev/null | \
  sha256sum | \
  awk '{print $1}' > hash

  # Set up kubeconfig for the non-root user
  echo "Setting up kubeconfig for the non-root user..."
  USER_HOME=$(eval echo ~${SUDO_USER})
  mkdir -p $USER_HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $USER_HOME/.kube/config
  sudo chown $SUDO_USER:$SUDO_USER $USER_HOME/.kube/config
  sudo chmod 600 $USER_HOME/.kube/config
  export KUBECONFIG=$USER_HOME/.kube/config

  # Also make kubectl accessible for root (optional)
  mkdir -p /root/.kube
  cp -i /etc/kubernetes/admin.conf /root/.kube/config
  chown root:root /root/.kube/config
  chmod 600 /root/.kube/config

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

  # Set up kubeconfig for the non-root user
  echo "Setting up kubeconfig for the non-root user..."
  USER_HOME=$(eval echo ~${SUDO_USER})
  mkdir -p $USER_HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $USER_HOME/.kube/config
  sudo chown $SUDO_USER:$SUDO_USER $USER_HOME/.kube/config
  sudo chmod 600 $USER_HOME/.kube/config
  export KUBECONFIG=$USER_HOME/.kube/config

  # Also make kubectl accessible for root (optional)
  mkdir -p /root/.kube
  cp -i /etc/kubernetes/admin.conf /root/.kube/config
  chown root:root /root/.kube/config
  chmod 600 /root/.kube/config

  echo "Worker node successfully joined the cluster!"
fi