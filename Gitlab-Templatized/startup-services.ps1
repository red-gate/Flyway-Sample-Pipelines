# Simple startup script for Rancher, Docker, and GitLab

Write-Host "Starting services..." -ForegroundColor Yellow
Write-Host ""

# Start Rancher
Write-Host "Starting Rancher..." -ForegroundColor Cyan
docker run -d --restart=unless-stopped `
    --name rancher `
    -p 80:80 -p 443:443 `
    --privileged `
    rancher/rancher:latest

# Start GitLab
Write-Host "Starting GitLab..." -ForegroundColor Cyan
docker run -d --restart=unless-stopped `
    --name gitlab `
    -p 8080:80 -p 8443:443 -p 2222:22 `
    -v gitlab-config:/etc/gitlab `
    -v gitlab-logs:/var/log/gitlab `
    -v gitlab-data:/var/opt/gitlab `
    gitlab/gitlab-ce:latest

Write-Host ""
Write-Host "Done! Services are starting up..." -ForegroundColor Green
Write-Host ""
Write-Host "Access URLs:"
Write-Host "  Rancher: http://localhost/dashboard/projects"
Write-Host "  GitLab:  http://localhost:8080"
Write-Host ""
