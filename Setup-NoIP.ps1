# No-IP Setup Script
# This script helps you set up the No-IP updater with .env configuration

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$envFile = Join-Path $scriptDir ".env"
$envExample = Join-Path $scriptDir ".env.example"
$gitignore = Join-Path $scriptDir ".gitignore"

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  No-IP Dynamic DNS Updater Setup" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Step 1: Create .gitignore if it doesn't exist
if (-not (Test-Path $gitignore)) {
    Write-Host "[1/4] Creating .gitignore..." -ForegroundColor Yellow
    @"
# Ignore sensitive configuration
.env

# Ignore logs
logs/
*.log

# Ignore temporary files
*.tmp
*.bak
"@ | Out-File -FilePath $gitignore -Encoding UTF8
    Write-Host "      ✓ .gitignore created" -ForegroundColor Green
} else {
    Write-Host "[1/4] .gitignore already exists" -ForegroundColor Gray
}

# Step 2: Check if .env exists
Write-Host "`n[2/4] Checking configuration..." -ForegroundColor Yellow
if (Test-Path $envFile) {
    Write-Host "      ⚠ .env file already exists" -ForegroundColor Yellow
    $overwrite = Read-Host "      Do you want to reconfigure? (y/N)"
    if ($overwrite -ne 'y' -and $overwrite -ne 'Y') {
        Write-Host "      Keeping existing configuration" -ForegroundColor Gray
        $skipConfig = $true
    }
}

# Step 3: Create .env file
if (-not $skipConfig) {
    Write-Host "`n[3/4] Setting up configuration..." -ForegroundColor Yellow
    
    # Prompt for No-IP credentials
    Write-Host "`n  No-IP Credentials:" -ForegroundColor Cyan
    $username = Read-Host "    Username"
    $password = Read-Host "    Password" -AsSecureString
    $passwordPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [Runtime.InteropServices.Marshal]::SecureStringToBSTR($password)
    )
    $hostname = Read-Host "    Hostname (e.g., myhouse.ddns.net)"
    
    # Prompt for IP configuration
    Write-Host "`n  IP Configuration:" -ForegroundColor Cyan
    Write-Host "    Which IP should be updated?" -ForegroundColor Gray
    Write-Host "      1 = Public IP (WAN) - for external access" -ForegroundColor Gray
    Write-Host "      2 = Local IP (LAN) - for internal network" -ForegroundColor Gray
    $ipChoice = Read-Host "    Choice (1 or 2)"
    
    $usePublicIP = 'true'
    $adapters = 'Wi-Fi,Ethernet'
    
    if ($ipChoice -eq '2') {
        $usePublicIP = 'false'
        $customAdapters = Read-Host "    Network adapters (default: Wi-Fi,Ethernet)"
        if (-not [string]::IsNullOrWhiteSpace($customAdapters)) {
            $adapters = $customAdapters
        }
    }
    
    # Prompt for log path
    Write-Host "`n  Logging:" -ForegroundColor Cyan
    $defaultLogPath = Join-Path $scriptDir "logs"
    $logPath = Read-Host "    Log directory (default: $defaultLogPath)"
    if ([string]::IsNullOrWhiteSpace($logPath)) {
        $logPath = $defaultLogPath
    }
    
    # Prompt for notifications
    Write-Host "`n  Notifications:" -ForegroundColor Cyan
    $showNotif = Read-Host "    Enable Windows notifications? (y/N)"
    $notifValue = if ($showNotif -eq 'y' -or $showNotif -eq 'Y') { 'true' } else { 'false' }
    
    # Ask about email alerts
    Write-Host "`n  Email Alerts (optional - press Enter to skip):" -ForegroundColor Cyan
    $smtpServer = Read-Host "    SMTP Server (e.g., smtp.gmail.com)"
    
    $emailConfig = ""
    if (-not [string]::IsNullOrWhiteSpace($smtpServer)) {
        $smtpPort = Read-Host "    SMTP Port (default: 587)"
        if ([string]::IsNullOrWhiteSpace($smtpPort)) { $smtpPort = "587" }
        $emailFrom = Read-Host "    From Email"
        $emailTo = Read-Host "    To Email"
        $emailPassword = Read-Host "    Email Password" -AsSecureString
        $emailPasswordPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
            [Runtime.InteropServices.Marshal]::SecureStringToBSTR($emailPassword)
        )
        
        $emailConfig = @"

# Email Alert Configuration
SMTP_SERVER=$smtpServer
SMTP_PORT=$smtpPort
EMAIL_FROM=$emailFrom
EMAIL_TO=$emailTo
EMAIL_PASSWORD=$emailPasswordPlain
"@
    }
    
    # Create .env file
    $envContent = @"
# No-IP Configuration
# NEVER commit this file to version control!
# Generated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

# No-IP Credentials
NOIP_USERNAME=$username
NOIP_PASSWORD=$passwordPlain
NOIP_HOSTNAME=$hostname

# IP Configuration
# USE_PUBLIC_IP: true = use public WAN IP, false = use local LAN IP
USE_PUBLIC_IP=$usePublicIP
# If USE_PUBLIC_IP=false, specify network adapters (comma-separated)
NETWORK_ADAPTERS=$adapters

# Logging Configuration
LOG_PATH=$logPath
MAX_LOG_SIZE_MB=10

# Notification Settings
SHOW_NOTIFICATIONS=$notifValue
$emailConfig
"@
    
    $envContent | Out-File -FilePath $envFile -Encoding UTF8
    Write-Host "`n      ✓ Configuration saved to .env" -ForegroundColor Green
    
    # Create log directory
    if (-not (Test-Path $logPath)) {
        New-Item -ItemType Directory -Path $logPath -Force | Out-Null
        Write-Host "      ✓ Log directory created: $logPath" -ForegroundColor Green
    }
} else {
    Write-Host "`n[3/4] Skipped configuration" -ForegroundColor Gray
}

# Step 4: Test configuration
Write-Host "`n[4/4] Testing configuration..." -ForegroundColor Yellow

$updateScript = Join-Path $scriptDir "Update-noip.ps1"
if (Test-Path $updateScript) {
    try {
        Write-Host "      Running test update..." -ForegroundColor Cyan
        & $updateScript -ShowNotification
        Write-Host "`n      ✓ Test completed! Check logs above for results." -ForegroundColor Green
    }
    catch {
        Write-Host "      ✗ Test failed: $($_.Exception.Message)" -ForegroundColor Red
    }
} else {
    Write-Host "      ⚠ Update-noip.ps1 not found" -ForegroundColor Yellow
}

# Summary
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  Setup Complete!" -ForegroundColor Green
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. Review your .env file: " -NoNewline -ForegroundColor Gray
Write-Host $envFile -ForegroundColor White
Write-Host "  2. Test the update script: " -NoNewline -ForegroundColor Gray
Write-Host ".\Update-noip.ps1 -ShowNotification" -ForegroundColor White
Write-Host "  3. Create scheduled task: " -NoNewline -ForegroundColor Gray
Write-Host ".\CreateTask.ps1" -ForegroundColor White
Write-Host "  4. Monitor the task: " -NoNewline -ForegroundColor Gray
Write-Host ".\Monitor-NoIPTask.ps1" -ForegroundColor White

Write-Host "`nImportant Security Notes:" -ForegroundColor Red
Write-Host "  • Never commit .env to version control" -ForegroundColor Gray
Write-Host "  • Keep your .env file permissions restricted" -ForegroundColor Gray
Write-Host "  • Rotate passwords regularly" -ForegroundColor Gray

# Offer to set file permissions
Write-Host "`nWould you like to restrict .env file permissions? (Recommended)" -ForegroundColor Yellow
$restrictPerms = Read-Host "Restrict to current user only? (Y/n)"
if ($restrictPerms -ne 'n' -and $restrictPerms -ne 'N') {
    try {
        $acl = Get-Acl $envFile
        $acl.SetAccessRuleProtection($true, $false)
        
        # Remove all existing rules
        $acl.Access | ForEach-Object { $acl.RemoveAccessRule($_) | Out-Null }
        
        # Add rule for current user only
        $rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
            $env:USERNAME,
            "FullControl",
            "Allow"
        )
        $acl.AddAccessRule($rule)
        Set-Acl $envFile $acl
        
        Write-Host "✓ File permissions restricted to current user" -ForegroundColor Green
    }
    catch {
        Write-Host "⚠ Could not set permissions: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

Write-Host ""