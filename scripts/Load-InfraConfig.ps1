#Requires -Version 5.1
<#
.SYNOPSIS
    Loads infrastructure configuration from config/infrastructure.env.

.DESCRIPTION
    Parses config/infrastructure.env and sets process-level environment variables.
    Existing environment variables take precedence over config file values.
    Dot-source this script from other PowerShell scripts:
        . "$PSScriptRoot\Load-InfraConfig.ps1"

.EXAMPLE
    . .\scripts\Load-InfraConfig.ps1
    echo $env:RA_POSTGRES_CONTAINER  # ra_postgres
#>

$script:_InfraConfigRoot = Split-Path -Parent $PSScriptRoot
$script:_InfraConfigFile = Join-Path $script:_InfraConfigRoot "config\infrastructure.env"

if (-not (Test-Path $script:_InfraConfigFile)) {
    Write-Warning "Infrastructure config not found: $script:_InfraConfigFile"
    Write-Warning "Copy config/infrastructure.env.example to config/infrastructure.env"
    return
}

Get-Content $script:_InfraConfigFile | ForEach-Object {
    $line = $_.Trim()

    # Skip empty lines and comments
    if ($line -eq '' -or $line.StartsWith('#')) {
        return
    }

    # Parse KEY=VALUE
    if ($line -match '^([A-Za-z_][A-Za-z0-9_]*)=(.*)$') {
        $key = $Matches[1]
        $value = $Matches[2]

        # Environment variable override: only set if not already defined
        $existing = [System.Environment]::GetEnvironmentVariable($key, 'Process')
        if ($null -eq $existing -or $existing -eq '') {
            [System.Environment]::SetEnvironmentVariable($key, $value, 'Process')
        }
    }
}
