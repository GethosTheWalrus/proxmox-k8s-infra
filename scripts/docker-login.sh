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

# Login to Docker Hub
if [ -n "$DOCKER_USERNAME" ] && [ -n "$DOCKER_PASSWORD" ]; then
    echo "Logging into Docker Hub..."
    echo "$DOCKER_PASSWORD" | docker login -u "$DOCKER_USERNAME" --password-stdin
else
    echo "Docker credentials not provided"
    exit 1
fi 