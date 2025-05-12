#!/bin/bash

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
    }
  }
}
EOF

# Set proper permissions
chmod 600 /root/.docker/config.json

# Verify login
echo "Verifying Docker Hub login..."
docker login -u "$DOCKER_USERNAME" -p "$DOCKER_PASSWORD" || {
    echo "Failed to login to Docker Hub"
    exit 1
}

echo "Successfully logged into Docker Hub" 