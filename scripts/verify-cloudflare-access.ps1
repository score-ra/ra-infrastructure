<![CDATA[<#
.SYNOPSIS
    Verify Cloudflare Access is enabled for tunneled domains.

.DESCRIPTION
    Checks if Cloudflare Access authentication is protecting the configured
    subdomains by detecting the Access login page redirect.

    When Access is enabled, unauthenticated requests receive a redirect to
    the Cloudflare Access login page. This script detects that redirect.

.PARAMETER Domain
    The base domain (default: selfwize.com)

.PARAMETER Subdomains
    Array of subdomains to check (default: wellness, stuff)

.EXAMPLE
    .\verify-cloudflare-access.ps1
    # Checks wellness.selfwize.com and stuff.selfwize.com

.EXAMPLE
    .\verify-cloudflare-access.ps1 -Subdomains @("wellness", "stuff", "app")
    # Checks three subdomains

.NOTES
    Author: Infrastructure Team
    Date: 2025-12-20
    Related: PRD-007-cloudflare-access-security.md
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$Domain = "selfwize.com",

    [Parameter(Mandatory=$false)]
    [string[]]$Subdomains = @("wellness", "stuff")
)

# Color output functions
function Write-Success {
    param([string]$Message)
    Write-Host "✓ " -ForegroundColor Green -NoNewline
    Write-Host $Message
}

function Write-Failure {
    param([string]$Message)
    Write-Host "✗ " -ForegroundColor Red -NoNewline
    Write-Host $Message
}

function Write-Warning-Custom {
    param([string]$Message)
    Write-Host "⚠ " -ForegroundColor Yellow -NoNewline
    Write-Host $Message
}

function Write-Info {
    param([string]$Message)
    Write-Host "ℹ " -ForegroundColor Cyan -NoNewline
    Write-Host $Message
}

# Main verification function
function Test-CloudflareAccess {
    param(
        [string]$Url
    )

    try {
        # Make request without following redirects
        $response = Invoke-WebRequest -Uri $Url -Method Get -MaximumRedirection 0 -ErrorAction SilentlyContinue -UseBasicParsing

        # If we get here, no redirect occurred (Access not enabled)
        return @{
            Enabled = $false
            StatusCode = $response.StatusCode
            Message = "No redirect detected (Access not enabled)"
        }
    }
    catch {
        $statusCode = $_.Exception.Response.StatusCode.Value__

        # Check if it's a redirect (302, 307)
        if ($statusCode -eq 302 -or $statusCode -eq 307) {
            $location = $_.Exception.Response.Headers.Location

            # Check if redirect is to Cloudflare Access
            if ($location -match "cloudflareaccess\.com" -or $location -match "\.cloudflareaccess\.com") {
                return @{
                    Enabled = $true
                    StatusCode = $statusCode
                    RedirectUrl = $location.AbsoluteUri
                    Message = "Cloudflare Access is enabled"
                }
            }
            else {
                return @{
                    Enabled = $false
                    StatusCode = $statusCode
                    RedirectUrl = $location.AbsoluteUri
                    Message = "Redirect to non-Access URL (Access not enabled)"
                }
            }
        }
        else {
            # Other error (could be 404, 502, etc.)
            return @{
                Enabled = $false
                StatusCode = $statusCode
                Message = "HTTP $statusCode - Unable to determine Access status"
            }
        }
    }
}

# Header
Write-Host ""
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host " Cloudflare Access Verification" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host "Domain: $Domain" -ForegroundColor White
Write-Host "Subdomains: $($Subdomains -join ', ')" -ForegroundColor White
Write-Host ""

# Results tracking
$results = @()

# Check each subdomain
foreach ($subdomain in $Subdomains) {
    $url = "https://$subdomain.$Domain"

    Write-Host "Checking: " -NoNewline
    Write-Host "$url" -ForegroundColor White
    Write-Host "  → " -NoNewline

    $result = Test-CloudflareAccess -Url $url

    # Store result
    $results += [PSCustomObject]@{
        Subdomain = "$subdomain.$Domain"
        Url = $url
        AccessEnabled = $result.Enabled
        StatusCode = $result.StatusCode
        Message = $result.Message
        RedirectUrl = $result.RedirectUrl
    }

    # Display result
    if ($result.Enabled) {
        Write-Success $result.Message
        if ($result.RedirectUrl) {
            Write-Host "    Redirect: " -ForegroundColor Gray -NoNewline
            Write-Host "$($result.RedirectUrl)" -ForegroundColor DarkGray
        }
    }
    else {
        Write-Failure $result.Message
        if ($result.RedirectUrl) {
            Write-Host "    Redirect: " -ForegroundColor Gray -NoNewline
            Write-Host "$($result.RedirectUrl)" -ForegroundColor DarkGray
        }
    }

    Write-Host ""
}

# Summary
Write-Host "───────────────────────────────────────────────────────" -ForegroundColor Gray
Write-Host "Summary" -ForegroundColor White
Write-Host "───────────────────────────────────────────────────────" -ForegroundColor Gray
Write-Host ""

$totalDomains = $results.Count
$protectedDomains = ($results | Where-Object { $_.AccessEnabled }).Count
$unprotectedDomains = $totalDomains - $protectedDomains

Write-Host "Total domains checked: " -NoNewline
Write-Host "$totalDomains" -ForegroundColor White

Write-Host "Protected by Access:   " -NoNewline
if ($protectedDomains -eq $totalDomains) {
    Write-Host "$protectedDomains" -ForegroundColor Green -NoNewline
    Write-Host " ✓" -ForegroundColor Green
}
else {
    Write-Host "$protectedDomains" -ForegroundColor Yellow
}

Write-Host "Not protected:         " -NoNewline
if ($unprotectedDomains -eq 0) {
    Write-Host "$unprotectedDomains" -ForegroundColor Green
}
else {
    Write-Host "$unprotectedDomains" -ForegroundColor Red
}

Write-Host ""

# Recommendations
if ($unprotectedDomains -gt 0) {
    Write-Host "───────────────────────────────────────────────────────" -ForegroundColor Gray
    Write-Host "Recommendations" -ForegroundColor Yellow
    Write-Host "───────────────────────────────────────────────────────" -ForegroundColor Gray
    Write-Host ""

    $unprotected = $results | Where-Object { -not $_.AccessEnabled }
    foreach ($item in $unprotected) {
        Write-Warning-Custom "Enable Cloudflare Access for: $($item.Subdomain)"
    }

    Write-Host ""
    Write-Host "See implementation guide:" -ForegroundColor Gray
    Write-Host "  docs/guides/CLOUDFLARE-ACCESS-IMPLEMENTATION.md" -ForegroundColor Cyan
    Write-Host ""
}
else {
    Write-Success "All configured domains are protected by Cloudflare Access!"
    Write-Host ""
}

# Detailed results table
Write-Host "───────────────────────────────────────────────────────" -ForegroundColor Gray
Write-Host "Detailed Results" -ForegroundColor White
Write-Host "───────────────────────────────────────────────────────" -ForegroundColor Gray
Write-Host ""

$results | Format-Table -Property @(
    @{Label="Subdomain"; Expression={$_.Subdomain}; Width=30},
    @{Label="Access"; Expression={if ($_.AccessEnabled) {"Enabled"} else {"Disabled"}}; Width=10},
    @{Label="Status"; Expression={$_.StatusCode}; Width=8},
    @{Label="Message"; Expression={$_.Message}; Width=40}
) -AutoSize

Write-Host ""

# Exit code
if ($protectedDomains -eq $totalDomains) {
    exit 0  # Success
}
else {
    exit 1  # Some domains not protected
}
]]>