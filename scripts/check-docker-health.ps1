<#
.SYNOPSIS
    Checks Docker health and attempts recovery if Docker is unresponsive.

.DESCRIPTION
    This script verifies that Docker daemon is operational. If Docker is not responding,
    it will attempt to restart Docker Desktop. Designed to be run manually or as a
    scheduled task watchdog.

.PARAMETER AutoRestart
    If specified, automatically restarts Docker Desktop when unhealthy.
    Without this flag, the script only reports status.

.EXAMPLE
    .\check-docker-health.ps1
    # Check status only

.EXAMPLE
    .\check-docker-health.ps1 -AutoRestart
    # Check and restart if unhealthy

.NOTES
    Created: 2025-12-30
    Related: docs/post-mortems/2025-12-30-docker-service-outage.md
#>

param(
    [switch]$AutoRestart
)

$ErrorActionPreference = "SilentlyContinue"

function Test-DockerHealth {
    try {
        $null = docker ps 2>&1
        return $LASTEXITCODE -eq 0
    }
    catch {
        return $false
    }
}

function Get-DockerServiceStatus {
    $service = Get-Service -Name 'com.docker.service' -ErrorAction SilentlyContinue
    if ($service) {
        return $service.Status
    }
    return "NotFound"
}

function Restart-DockerDesktop {
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Stopping Docker Desktop..." -ForegroundColor Yellow
    Stop-Process -Name 'Docker Desktop' -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 5

    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Starting Docker Desktop..." -ForegroundColor Yellow
    Start-Process 'C:\Program Files\Docker\Docker\Docker Desktop.exe'

    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Waiting for Docker to initialize (60s)..." -ForegroundColor Yellow
    Start-Sleep -Seconds 60

    return Test-DockerHealth
}

# Main execution
Write-Host ""
Write-Host "=== Docker Health Check ===" -ForegroundColor Cyan
Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Checking Docker status..."

$serviceStatus = Get-DockerServiceStatus
$dockerHealthy = Test-DockerHealth

Write-Host ""
Write-Host "Service Status: " -NoNewline
if ($serviceStatus -eq "Running") {
    Write-Host $serviceStatus -ForegroundColor Green
} else {
    Write-Host $serviceStatus -ForegroundColor Red
}

Write-Host "Docker Daemon:  " -NoNewline
if ($dockerHealthy) {
    Write-Host "Responsive" -ForegroundColor Green

    # Show container count
    $containers = docker ps --format "{{.Names}}" 2>&1
    $count = ($containers | Measure-Object -Line).Lines
    Write-Host "Containers:     $count running" -ForegroundColor Green
} else {
    Write-Host "NOT RESPONDING" -ForegroundColor Red

    if ($AutoRestart) {
        Write-Host ""
        Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Attempting automatic recovery..." -ForegroundColor Yellow

        $recovered = Restart-DockerDesktop

        Write-Host ""
        if ($recovered) {
            Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Recovery SUCCESSFUL - Docker is now operational" -ForegroundColor Green
            $containers = docker ps --format "{{.Names}}" 2>&1
            $count = ($containers | Measure-Object -Line).Lines
            Write-Host "[$(Get-Date -Format 'HH:mm:ss')] $count containers running" -ForegroundColor Green
            exit 0
        } else {
            Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Recovery FAILED - manual intervention required" -ForegroundColor Red
            Write-Host ""
            Write-Host "Try these steps:" -ForegroundColor Yellow
            Write-Host "  1. Open Docker Desktop manually"
            Write-Host "  2. Check Windows Event Viewer for errors"
            Write-Host "  3. Run as Admin: Start-Service -Name 'com.docker.service'"
            exit 1
        }
    } else {
        Write-Host ""
        Write-Host "To attempt recovery, run:" -ForegroundColor Yellow
        Write-Host "  .\check-docker-health.ps1 -AutoRestart" -ForegroundColor White
        exit 1
    }
}

Write-Host ""
exit 0
