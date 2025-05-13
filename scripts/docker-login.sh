#!/bin/bash

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "Docker is not installed. Installing Docker..."
    
    # Update package list
    apt-get update
    
    # Install prerequisites
    apt-get install -y \
        apt-transport-https \
        ca-certificates \
        curl \
        gnupg \
        lsb-release
    
    # Add Docker's official GPG key
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    
    # Set up the stable repository
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Update package list again
    apt-get update
    
    # Install Docker Engine
    apt-get install -y docker-ce docker-ce-cli containerd.io
    
    # Start and enable Docker service
    systemctl start docker
    systemctl enable docker
    
    echo "Docker has been installed successfully."
else
    echo "Docker is already installed."
fi

# Check if required variables are set
if [ -z "$DOCKER_USERNAME" ] || [ -z "$DOCKER_PASSWORD" ]; then
    echo "Error: DOCKER_USERNAME and DOCKER_PASSWORD must be set"
    exit 1
fi

# Create Docker config directory if it doesn't exist
mkdir -p /root/.docker

# Create or update Docker config file
cat > /root/.docker/config.json << EOF
{
  "auths": {
    "https://index.docker.io/v1/": {
      "auth": "$(echo -n "$DOCKER_USERNAME:$DOCKER_PASSWORD" | base64)"
    },
    "http://git.home:5050": {
      "auth": "$(echo -n "$DOCKER_USERNAME:$DOCKER_PASSWORD" | base64)"
    }
  },
  "insecure-registries": ["git.home:5050"]
}
EOF

# Set proper permissions
chmod 600 /root/.docker/config.json

# Configure Docker daemon to use insecure registry
mkdir -p /etc/docker
cat > /etc/docker/daemon.json << EOF
{
  "insecure-registries": ["git.home:5050"]
}
EOF

# Restart Docker daemon to apply changes
if command -v systemctl &> /dev/null; then
    systemctl restart docker
elif command -v service &> /dev/null; then
    service docker restart
fi

# Verify Docker Hub login
echo "Verifying Docker Hub login..."
docker login -u "$DOCKER_USERNAME" -p "$DOCKER_PASSWORD" || {
    echo "Failed to login to Docker Hub"
    exit 1
}

# Verify GitLab registry login
echo "Verifying GitLab registry login..."
docker login -u "$DOCKER_USERNAME" -p "$DOCKER_PASSWORD" http://git.home:5050 || {
    echo "Failed to login to GitLab registry"
    exit 1
}

echo "Successfully logged into Docker Hub and GitLab registry" 