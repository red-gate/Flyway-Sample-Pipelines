# Simple startup script for Rancher, Docker, and GitLab
#
# Fixed IP addresses (on gitlab-net 172.30.0.0/24):
#   Rancher:       172.30.0.10  →  host ports 80 / 443
#   GitLab:        172.30.0.2   →  host ports 8080 / 8443 / 2222
#   GitLab Runner: 172.30.0.3   →  no host ports
#
# Passwords are read from .env and injected on first container creation.
# Rancher and GitLab data are stored in named Docker volumes so state
# (including passwords) survives container recreation.

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

# ---------------------------------------------------------------------------
# Helper: start an existing stopped container, or create a new one.
# Returns $true if the container was already running.
# ---------------------------------------------------------------------------
function Start-OrCreate {
    param([string]$Name)
    $state = docker inspect --format '{{.State.Running}}' $Name 2>&1
    if ($LASTEXITCODE -eq 0) {
        if ($state -eq 'true') {
            Write-Host "$Name is already running." -ForegroundColor Gray
            return $true
        }
        Write-Host "Starting existing $Name container..." -ForegroundColor Cyan
        docker start $Name | Out-Null
        return $true
    }
    return $false   # container does not exist — caller will create it
}

# ---------------------------------------------------------------------------
# Rancher  (172.30.0.10 — ports 80/443)
# ---------------------------------------------------------------------------
Write-Host "Starting Rancher..." -ForegroundColor Cyan
if (-not (Start-OrCreate "rancher")) {
    $rancherPw = $env:RANCHER_BOOTSTRAP_PASSWORD
    $rancherEnv = @()
    if ($rancherPw) { $rancherEnv = @("-e", "CATTLE_BOOTSTRAP_PASSWORD=$rancherPw") }

    docker run -d --restart=unless-stopped `
        --name rancher `
        --network gitlab-net --ip 172.30.0.10 `
        -p 80:80 -p 443:443 `
        --privileged `
        -v rancher-data:/var/lib/rancher `
        @rancherEnv `
        rancher/rancher:latest | Out-Null
    if ($rancherPw) {
        Write-Host "  Rancher bootstrap password set from .env" -ForegroundColor Green
    }
}

# ---------------------------------------------------------------------------
# GitLab  (172.30.0.2 — ports 8080/8443/2222)
# ---------------------------------------------------------------------------
Write-Host "Starting GitLab..." -ForegroundColor Cyan
if (-not (Start-OrCreate "gitlab")) {
    $gitlabPw  = $env:GITLAB_ROOT_PASSWORD
    $gitlabUrl = $env:GITLAB_EXTERNAL_URL
    $gitlabEnv = @()
    if ($gitlabPw)  { $gitlabEnv += @("-e", "GITLAB_ROOT_PASSWORD=$gitlabPw") }
    if ($gitlabUrl) { $gitlabEnv += @("-e", "GITLAB_OMNIBUS_CONFIG=external_url '$gitlabUrl'") }

    docker run -d --restart=unless-stopped `
        --name gitlab `
        --network gitlab-net --ip 172.30.0.2 `
        -p 8080:80 -p 8443:443 -p 2222:22 `
        -v gitlab-config:/etc/gitlab `
        -v gitlab-logs:/var/log/gitlab `
        -v gitlab-data:/var/opt/gitlab `
        @gitlabEnv `
        gitlab/gitlab-ce:latest | Out-Null
    if ($gitlabPw) {
        Write-Host "  GitLab root password set from .env" -ForegroundColor Green
    }
}

# ---------------------------------------------------------------------------
# GitLab Runner  (172.30.0.3)
# ---------------------------------------------------------------------------
Write-Host "Starting GitLab Runner..." -ForegroundColor Cyan
if (-not (Start-OrCreate "gitlab-runner")) {
    docker run -d --restart=unless-stopped `
        --name gitlab-runner `
        --network gitlab-net --ip 172.30.0.3 `
        -v gitlab-runner-config:/etc/gitlab-runner `
        -v //var/run/docker.sock:/var/run/docker.sock `
        gitlab/gitlab-runner:latest | Out-Null
}

# ---------------------------------------------------------------------------
# Register runner if not already registered
# ---------------------------------------------------------------------------
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

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host " All services started!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host "  Rancher:  https://localhost       (172.30.0.10)" -ForegroundColor White
Write-Host "  GitLab:   http://localhost:8080   (172.30.0.2)" -ForegroundColor White
Write-Host "  Runner:   connected on gitlab-net (172.30.0.3)" -ForegroundColor White
Write-Host ""
Write-Host "  GitLab user: root" -ForegroundColor White
Write-Host "  Passwords:   see .env file" -ForegroundColor White
Write-Host "========================================"  -ForegroundColor Green

Write-Host ""
Write-Host "Done! Services are starting up..." -ForegroundColor Green
Write-Host ""
Write-Host "Access URLs:"
Write-Host "  Rancher: http://localhost/dashboard/projects"
Write-Host "  GitLab:  http://localhost:8080"
Write-Host ""
