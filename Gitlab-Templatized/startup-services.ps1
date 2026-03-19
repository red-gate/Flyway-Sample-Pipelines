# Simple startup script for Rancher, Docker, and GitLab

# Load environment variables from .env file
$envFile = Join-Path $PSScriptRoot ".env"
if (Test-Path $envFile) {
    Get-Content $envFile | ForEach-Object {
        if ($_ -match '^\s*([^#][^=]+)=(.*)$') {
            [System.Environment]::SetEnvironmentVariable($Matches[1].Trim(), $Matches[2].Trim(), "Process")
        }
    }
    Write-Host "Loaded environment from .env" -ForegroundColor Gray
}

Write-Host "Starting services..." -ForegroundColor Yellow
Write-Host ""

# Create a dedicated Docker network with a fixed subnet (idempotent)
$networkName = "gitlab-net"
$subnet = "172.30.0.0/24"
$networkExists = docker network ls --filter "name=^${networkName}$" --format '{{.Name}}' 2>&1
if ($networkExists -ne $networkName) {
    Write-Host "Creating Docker network '$networkName' (subnet $subnet)..." -ForegroundColor Cyan
    docker network create --subnet $subnet $networkName | Out-Null
} else {
    Write-Host "Docker network '$networkName' already exists." -ForegroundColor Gray
}

# Ensure Rancher Desktop is running
if (-not (Get-Process "Rancher Desktop" -ErrorAction SilentlyContinue)) {
    Write-Host "Rancher Desktop is not running. Starting it..." -ForegroundColor Yellow
    Start-Process "C:\Program Files\Rancher Desktop\Rancher Desktop.exe"
    Write-Host "Waiting for Docker daemon to be ready..." -ForegroundColor Yellow
    $timeout = 120
    $elapsed = 0
    while ($elapsed -lt $timeout) {
        $result = docker info 2>&1
        if ($LASTEXITCODE -eq 0) { break }
        Start-Sleep -Seconds 2
        $elapsed += 2
    }
    if ($elapsed -ge $timeout) {
        Write-Host "ERROR: Docker daemon did not start within $timeout seconds." -ForegroundColor Red
        exit 1
    }
    Write-Host "Docker is ready!" -ForegroundColor Green
}

# Start Rancher
Write-Host "Starting Rancher..." -ForegroundColor Cyan
docker run -d --restart=unless-stopped `
    --name rancher `
    --network gitlab-net --ip 172.30.0.10 `
    -p 80:80 -p 443:443 `
    --privileged `
    rancher/rancher:latest

# Start GitLab
Write-Host "Starting GitLab..." -ForegroundColor Cyan
docker run -d --restart=unless-stopped `
    --name gitlab `
    --network gitlab-net --ip 172.30.0.2 `
    -p 8080:80 -p 8443:443 -p 2222:22 `
    -v gitlab-config:/etc/gitlab `
    -v gitlab-logs:/var/log/gitlab `
    -v gitlab-data:/var/opt/gitlab `
    gitlab/gitlab-ce:latest

# Start GitLab Runner
Write-Host "Starting GitLab Runner..." -ForegroundColor Cyan
docker run -d --restart=unless-stopped `
    --name gitlab-runner `
    --network gitlab-net --ip 172.30.0.3 `
    -v gitlab-runner-config:/etc/gitlab-runner `
    -v //var/run/docker.sock:/var/run/docker.sock `
    gitlab/gitlab-runner:latest

# Register runner if not already registered
$runnerConfig = docker exec gitlab-runner cat /etc/gitlab-runner/config.toml 2>&1
if ($runnerConfig -notmatch '\[\[runners\]\]') {
    $token = $env:GITLAB_RUNNER_REGISTRATION_TOKEN
    $url   = $env:GITLAB_URL
    if ($token -and $url) {
        Write-Host "Registering GitLab Runner..." -ForegroundColor Yellow
        docker exec gitlab-runner gitlab-runner register `
            --non-interactive `
            --url $url `
            --registration-token $token `
            --executor "docker" `
            --docker-image "redgate/flyway:12-enterprise-alpine" `
            --description "local-runner" `
            --tag-list "local-runner" `
            --run-untagged="true" `
            --locked="false" `
            --docker-network-mode "gitlab-net" `
            --clone-url $url
    } else {
        Write-Host "WARNING: GITLAB_RUNNER_REGISTRATION_TOKEN or GITLAB_URL not set in .env - skipping registration." -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "Done! Services are starting up..." -ForegroundColor Green
Write-Host ""
Write-Host "Access URLs:"
Write-Host "  Rancher: http://localhost/dashboard/projects"
Write-Host "  GitLab:  http://localhost:8080"
Write-Host ""
