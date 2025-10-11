# Windows PowerShell Remoting Setup Guide

Guide for enabling PowerShell remoting on Windows computers to allow remote management and administration.

## Overview

PowerShell Remoting uses Windows Remote Management (WinRM) to enable remote command execution and interactive sessions between Windows computers. This guide covers setup for both the target computer (the one being accessed remotely) and the client computer (the one initiating the connection).

## Prerequisites

- **Operating System:** Windows 10/11 or Windows Server 2012+
- **Network:** Both computers must be network-accessible to each other
- **Credentials:** Administrator access on the target computer
- **Firewall:** WinRM ports must be allowed (5985 for HTTP, 5986 for HTTPS)

## Target Computer Setup

The target computer is the machine you want to connect TO remotely.

### 1. Enable PowerShell Remoting

Open PowerShell as Administrator and run:

```powershell
# Enable PowerShell Remoting (configures WinRM service and firewall rules)
Enable-PSRemoting -Force
```

This command will:
- Start the WinRM service
- Set WinRM service to start automatically
- Create firewall rules for WinRM
- Create a listener to accept requests on any IP address

### 2. Configure Windows Firewall

If you need to allow connections from any remote address:

```powershell
# Allow remote connections through Windows Firewall from any address
Set-NetFirewallRule -Name "WINRM-HTTP-In-TCP" -RemoteAddress Any

# Or specify specific IP addresses/ranges
Set-NetFirewallRule -Name "WINRM-HTTP-In-TCP" -RemoteAddress "192.168.1.0/24"
```

### 3. Configure TrustedHosts (Non-Domain Environment)

If computers are NOT on the same Active Directory domain, configure TrustedHosts:

```powershell
# Trust all computers (less secure, convenient for home/lab)
Set-Item WSMan:\localhost\Client\TrustedHosts -Value "*" -Force

# Or trust specific computers by hostname
Set-Item WSMan:\localhost\Client\TrustedHosts -Value "CLIENT-PC" -Force

# Or trust specific IP addresses
Set-Item WSMan:\localhost\Client\TrustedHosts -Value "192.168.1.100" -Force

# Or trust multiple computers (comma-separated)
Set-Item WSMan:\localhost\Client\TrustedHosts -Value "CLIENT-PC,192.168.1.100,LAPTOP01" -Force
```

**Note:** TrustedHosts is only required for non-domain environments. Domain-joined computers automatically trust each other.

### 4. Verify WinRM Service Status

```powershell
# Check if WinRM service is running
Get-Service WinRM

# View WinRM configuration
winrm get winrm/config

# View current listeners
Get-WSManInstance -ResourceURI winrm/config/listener -Enumerate
```

### 5. Test WinRM Connectivity (Optional)

```powershell
# Test WinRM from the same computer
Test-WSMan -ComputerName localhost
```

## Client Computer Setup

The client computer is the machine you're connecting FROM.

### 1. Configure TrustedHosts (Non-Domain Environment)

On the client computer, add the target computer to TrustedHosts:

```powershell
# Add target computer to TrustedHosts
Set-Item WSMan:\localhost\Client\TrustedHosts -Value "TARGET-PC" -Force

# Or by IP address
Set-Item WSMan:\localhost\Client\TrustedHosts -Value "192.168.1.50" -Force

# View current TrustedHosts
Get-Item WSMan:\localhost\Client\TrustedHosts
```

### 2. Test Remote Connection

```powershell
# Test WinRM connectivity to target computer
Test-WSMan -ComputerName TARGET-PC

# Or by IP address
Test-WSMan -ComputerName 192.168.1.50
```

## Connecting to Remote Computer

### Interactive Session

```powershell
# Start interactive remote session (will prompt for credentials)
Enter-PSSession -ComputerName TARGET-PC -Credential (Get-Credential)

# Or using IP address
Enter-PSSession -ComputerName 192.168.1.50 -Credential (Get-Credential)

# Exit the remote session
Exit-PSSession
```

### Execute Remote Commands

```powershell
# Execute a single command remotely
Invoke-Command -ComputerName TARGET-PC -Credential (Get-Credential) -ScriptBlock {
    Get-Process
}

# Execute multiple commands
Invoke-Command -ComputerName TARGET-PC -Credential (Get-Credential) -ScriptBlock {
    $env:COMPUTERNAME
    Get-Service | Where-Object {$_.Status -eq 'Running'}
    Get-Disk
}

# Run a local script on remote computer
Invoke-Command -ComputerName TARGET-PC -Credential (Get-Credential) -FilePath "C:\Scripts\MyScript.ps1"
```

### Store Credentials (Optional)

```powershell
# Save credentials to a variable (valid for current session only)
$cred = Get-Credential

# Use stored credentials
Enter-PSSession -ComputerName TARGET-PC -Credential $cred
```

## Network Configuration

### Default Ports

- **HTTP (Default):** 5985
- **HTTPS (Secure):** 5986

### Finding Computer Name/IP

On the target computer:

```powershell
# Get computer name
$env:COMPUTERNAME

# Get IP address
Get-NetIPAddress -AddressFamily IPv4 | Where-Object {$_.InterfaceAlias -notlike "*Loopback*"}

# Get hostname
hostname
```

## Security Considerations

### Best Practices

1. **Use HTTPS when possible** - HTTP transmits data unencrypted
2. **Limit TrustedHosts** - Specify exact computers instead of "*"
3. **Use strong passwords** - Ensure all accounts have strong credentials
4. **Enable firewall rules only for required IP ranges** - Don't use "Any" in production
5. **Regular auditing** - Monitor remote access logs
6. **Disable when not needed** - Disable remoting on computers that don't require it

### Viewing TrustedHosts

```powershell
# View current TrustedHosts configuration
Get-Item WSMan:\localhost\Client\TrustedHosts

# Clear TrustedHosts
Clear-Item WSMan:\localhost\Client\TrustedHosts -Force
```

### Disable PowerShell Remoting

If you need to disable remoting:

```powershell
# Disable PowerShell Remoting
Disable-PSRemoting -Force

# Stop WinRM service
Stop-Service WinRM

# Set WinRM to manual start
Set-Service WinRM -StartupType Manual
```

## Troubleshooting

### Connection Failures

**Issue:** "Connecting to remote server failed"

```powershell
# Verify WinRM service is running on target
Test-WSMan -ComputerName TARGET-PC

# Check if target is in TrustedHosts
Get-Item WSMan:\localhost\Client\TrustedHosts

# Verify firewall rules
Get-NetFirewallRule -Name "WINRM-HTTP-In-TCP"
```

**Issue:** "Access is denied"

- Ensure you're using credentials with Administrator rights on target computer
- Verify the account is not disabled
- Check if UAC is blocking remote administration

**Issue:** "The WinRM client cannot process the request"

- Add target computer to TrustedHosts on client computer
- Verify network connectivity (ping, traceroute)

### Network Connectivity

```powershell
# Test basic network connectivity
Test-Connection -ComputerName TARGET-PC -Count 4

# Test specific port (5985)
Test-NetConnection -ComputerName TARGET-PC -Port 5985

# Verify DNS resolution
Resolve-DnsName TARGET-PC
```

### Firewall Issues

```powershell
# List all WinRM firewall rules
Get-NetFirewallRule | Where-Object {$_.Name -like "*WINRM*"}

# Enable WinRM firewall rule if disabled
Enable-NetFirewallRule -Name "WINRM-HTTP-In-TCP"

# Check if Windows Firewall is blocking
Get-NetFirewallProfile
```

## Domain Environment Differences

### Domain-Joined Computers

For computers on the same Active Directory domain:

- **TrustedHosts not required** - Domain trust handles authentication
- **Kerberos authentication used** - More secure than NTLM
- **Group Policy can enable remoting** - Centralized management

```powershell
# Connect using current domain credentials
Enter-PSSession -ComputerName TARGET-PC

# Specify different domain credentials
Enter-PSSession -ComputerName TARGET-PC -Credential DOMAIN\Username
```

## Advanced Configuration

### Configure HTTPS Listener

For secure encrypted connections:

```powershell
# Create self-signed certificate (for testing only)
$cert = New-SelfSignedCertificate -DnsName "TARGET-PC" -CertStoreLocation Cert:\LocalMachine\My

# Create HTTPS listener
New-WSManInstance -ResourceURI winrm/config/Listener -SelectorSet @{Address="*";Transport="HTTPS"} -ValueSet @{Hostname="TARGET-PC";CertificateThumbprint=$cert.Thumbprint}

# Update firewall for HTTPS
New-NetFirewallRule -Name "WINRM-HTTPS-In-TCP" -DisplayName "Windows Remote Management (HTTPS-In)" -Enabled True -Direction Inbound -Protocol TCP -LocalPort 5986
```

### Session Configuration

```powershell
# View available session configurations
Get-PSSessionConfiguration

# Create custom session configuration
Register-PSSessionConfiguration -Name "CustomSession" -StartupScript "C:\Scripts\SessionStartup.ps1"
```

## Quick Reference

### Target Computer Setup (One-Time)

```powershell
# Run as Administrator
Enable-PSRemoting -Force
Set-NetFirewallRule -Name "WINRM-HTTP-In-TCP" -RemoteAddress Any
Set-Item WSMan:\localhost\Client\TrustedHosts -Value "*" -Force
```

### Client Computer Setup (One-Time)

```powershell
# Run as Administrator
Set-Item WSMan:\localhost\Client\TrustedHosts -Value "TARGET-PC" -Force
```

### Connect to Remote Computer

```powershell
# Interactive session
Enter-PSSession -ComputerName TARGET-PC -Credential (Get-Credential)

# Execute command
Invoke-Command -ComputerName TARGET-PC -Credential (Get-Credential) -ScriptBlock { Get-Service }
```

## Related Documentation

- [Windows Remote Management Documentation](https://docs.microsoft.com/en-us/windows/win32/winrm/portal)
- [PowerShell Remoting Security](https://docs.microsoft.com/en-us/powershell/scripting/learn/remoting/winrmsecurity)
- [About Remote Troubleshooting](https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_remote_troubleshooting)

## Additional Resources

### WinRM Quick Configuration

```powershell
# Quick setup with default settings
winrm quickconfig

# Set authentication methods
winrm set winrm/config/service/Auth @{Basic="true"}
winrm set winrm/config/client/Auth @{Basic="true"}
```

### Performance Tuning

```powershell
# Increase max concurrent operations
Set-Item WSMan:\localhost\Config\MaxConcurrentOperations -Value 100

# Increase max envelope size (for large data transfers)
Set-Item WSMan:\localhost\Config\MaxEnvelopeSizekb -Value 500

# Increase timeout values
Set-Item WSMan:\localhost\Config\MaxTimeoutms -Value 60000
```

---

**Document Version:** 1.0
**Last Updated:** 2025-10-06
**Author:** Symphony Core Infrastructure Team
