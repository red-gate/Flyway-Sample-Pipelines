# Simple startup script for Rancher, Docker, Harness, and SQL Server
#
# Fixed IP addresses (on harness-net 172.31.0.0/24):
#   Rancher:       172.31.0.10  →  host ports 80 / 443
#   Harness:       172.31.0.2   →  host ports 3005 / 3022
#   SQL Server:    172.31.0.4   →  host port 1434
#
# Passwords are read from .env and injected on first container creation.
# Data is stored in named Docker volumes so state survives container recreation.

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

Write-Host 'Starting services...' -ForegroundColor Yellow
Write-Host ''

# Create a dedicated Docker network with a fixed subnet (idempotent)
$networkName = "harness-net"
$subnet = "172.31.0.0/24"
$existingNetworks = docker network ls --format '{{.Name}}' 2>&1
if ($existingNetworks -notcontains $networkName) {
    Write-Host "Creating Docker network '$networkName' (subnet $subnet)..." -ForegroundColor Cyan
    docker network create --subnet $subnet $networkName | Out-Null
} else {
    Write-Host "Docker network '$networkName' already exists." -ForegroundColor Gray
}

# Ensure Rancher Desktop is running
if (-not (Get-Process "Rancher Desktop" -ErrorAction SilentlyContinue)) {
    Write-Host 'Rancher Desktop is not running. Starting it...' -ForegroundColor Yellow
    Start-Process "C:\Program Files\Rancher Desktop\Rancher Desktop.exe"
    Write-Host 'Waiting for Docker daemon to be ready...' -ForegroundColor Yellow
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
# Rancher  (172.31.0.10 — ports 80/443)
# ---------------------------------------------------------------------------
Write-Host "Starting Rancher..." -ForegroundColor Cyan
if (-not (Start-OrCreate "rancher")) {
    $rancherPw = $env:RANCHER_BOOTSTRAP_PASSWORD
    $rancherEnv = @()
    if ($rancherPw) { $rancherEnv = @("-e", "CATTLE_BOOTSTRAP_PASSWORD=$rancherPw") }

    docker run -d --restart=unless-stopped `
        --name rancher `
        --network harness-net --ip 172.31.0.10 `
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
# Harness  (172.31.0.2 — ports 3005/3022)
# ---------------------------------------------------------------------------
Write-Host "Starting Harness..." -ForegroundColor Cyan
if (-not (Start-OrCreate "harness")) {
    docker run -d --restart=unless-stopped `
        --name harness `
        --network harness-net --ip 172.31.0.2 `
        -p 3005:3000 -p 3022:3022 `
        -v //var/run/docker.sock:/var/run/docker.sock `
        -v harness-data:/data `
        harness/harness | Out-Null
    Write-Host "  Harness started on port 3005" -ForegroundColor Green
}

# ---------------------------------------------------------------------------
# SQL Server  (172.31.0.4 — port 1434)
# ---------------------------------------------------------------------------
Write-Host "Starting SQL Server..." -ForegroundColor Cyan
if (-not (Start-OrCreate "sqlserver-dev")) {
    $sqlPw = $env:SQL_SA_PASSWORD
    if (-not $sqlPw) { $sqlPw = 'Flyway2026!Secure' }

    docker run -d --restart=unless-stopped `
        --name sqlserver-dev `
        --network harness-net --ip 172.31.0.4 `
        -p 1434:1433 `
        -e "ACCEPT_EULA=Y" `
        -e "MSSQL_SA_PASSWORD=$sqlPw" `
        -v sqldev-data:/var/opt/mssql `
        mcr.microsoft.com/mssql/server:2022-latest | Out-Null
    Write-Host "  SQL Server sa password set from .env" -ForegroundColor Green
}

# ---------------------------------------------------------------------------
# Wait for Harness to be ready
# ---------------------------------------------------------------------------
Write-Host 'Waiting for Harness to be ready (this can take a few minutes)...' -ForegroundColor Yellow
$harnessTimeout = 300
$harnessElapsed = 0
while ($harnessElapsed -lt $harnessTimeout) {
    try {
        $response = Invoke-WebRequest -Uri 'http://localhost:3005/api/v1/system/health' -UseBasicParsing -TimeoutSec 5 -ErrorAction SilentlyContinue
        if ($response.StatusCode -eq 200) { break }
    } catch {}
    Write-Host "  Harness not ready yet... ($harnessElapsed s)" -ForegroundColor Gray
    Start-Sleep -Seconds 10
    $harnessElapsed += 10
}
if ($harnessElapsed -ge $harnessTimeout) {
    Write-Host "  Harness did not become ready within $harnessTimeout s - it may still be starting up." -ForegroundColor Yellow
} else {
    Write-Host "Harness is ready!" -ForegroundColor Green
}

# ---------------------------------------------------------------------------
# Pull Flyway Docker image (used by Harness pipelines)
# ---------------------------------------------------------------------------
Write-Host 'Pulling Flyway Docker image...' -ForegroundColor Cyan
$flywayImage = $env:FLYWAY_DOCKER_IMAGE
if (-not $flywayImage) { $flywayImage = "redgate/flyway:latest" }
docker pull $flywayImage | Out-Null
Write-Host "  Flyway image ready: $flywayImage" -ForegroundColor Green

# ---------------------------------------------------------------------------
# Retrieve Rancher bootstrap password
# ---------------------------------------------------------------------------
$rancherBootstrapPw = $null
if ($env:RANCHER_BOOTSTRAP_PASSWORD) {
    $rancherBootstrapPw = $env:RANCHER_BOOTSTRAP_PASSWORD
} else {
    Write-Host 'Retrieving Rancher bootstrap password from logs...' -ForegroundColor Yellow
    $pwTimeout = 120
    $pwElapsed = 0
    while ($pwElapsed -lt $pwTimeout) {
        $logLine = docker logs rancher 2>&1 | Select-String 'Bootstrap Password:' | Select-Object -Last 1
        if ($logLine) {
            $rancherBootstrapPw = ($logLine -replace '.*Bootstrap Password:\s*', '').Trim()
            break
        }
        Start-Sleep -Seconds 5
        $pwElapsed += 5
    }
    if (-not $rancherBootstrapPw) {
        Write-Host "  Could not retrieve bootstrap password from logs within $pwTimeout s" -ForegroundColor Yellow
    }
}

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host " All services started!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host '  Rancher:     https://localhost         (172.31.0.10)' -ForegroundColor White
Write-Host '  Harness:     http://localhost:3005     (172.31.0.2)' -ForegroundColor White
Write-Host '  SQL Server:  localhost,1434            (172.31.0.4)' -ForegroundColor White
Write-Host "  Flyway:      $flywayImage (image pulled)" -ForegroundColor White
Write-Host ""
if ($rancherBootstrapPw) {
    Write-Host "  Rancher password:  $rancherBootstrapPw" -ForegroundColor White
} else {
    Write-Host '  Rancher password:  (unknown - check: docker logs rancher 2>&1 | Select-String "Bootstrap Password:")' -ForegroundColor Yellow
}
Write-Host '========================================' -ForegroundColor Green

Write-Host ''
Write-Host 'Done! Services are starting up...' -ForegroundColor Green
Write-Host ''
Write-Host 'Access URLs:'
Write-Host '  Rancher: https://localhost/dashboard/projects'
Write-Host '  Harness: http://localhost:3005'
Write-Host ''
