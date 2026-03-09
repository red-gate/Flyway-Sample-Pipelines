#!/bin/bash
# Simple startup script for Rancher, Docker, and GitLab

echo "Starting services..."
echo ""

# Start Rancher
echo "Starting Rancher..."
docker run -d --restart=unless-stopped \
    --name rancher \
    -p 80:80 -p 443:443 \
    --privileged \
    rancher/rancher:latest

# Start GitLab
echo "Starting GitLab..."
docker run -d --restart=unless-stopped \
    --name gitlab \
    -p 8080:80 -p 8443:443 -p 2222:22 \
    -v gitlab-config:/etc/gitlab \
    -v gitlab-logs:/var/log/gitlab \
    -v gitlab-data:/var/opt/gitlab \
    gitlab/gitlab-ce:latest

echo ""
echo "Done! Services are starting up..."
echo ""
echo "Access URLs:"
echo "  Rancher: https://localhost"
echo "  GitLab:  http://localhost:8080"
echo ""
