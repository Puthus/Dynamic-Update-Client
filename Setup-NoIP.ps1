# No-IP Complete Setup Script
# Combines configuration setup and scheduled task creation
# Run this script once to configure everything

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$envFile = Join-Path $scriptDir ".env"
# $envExample = Join-Path $scriptDir ".env.example"
$gitignore = Join-Path $scriptDir ".gitignore"

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  No-IP Complete Setup Wizard" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

#region Step 1: Create .gitignore if it doesn't exist
if (-not (Test-Path $gitignore)) {
    Write-Host "[1/6] Creating .gitignore..." -ForegroundColor Yellow
    @"
# Ignore sensitive configuration
.env

# Ignore logs
logs/
*.log

# Ignore temporary files
*.tmp
*.bak
*.csv
"@ | Out-File -FilePath $gitignore -Encoding UTF8
    Write-Host "      ✓ .gitignore created" -ForegroundColor Green
}
else {
    Write-Host "[1/6] .gitignore already exists" -ForegroundColor Gray
}
#endregion

#region Step 2: Check existing configuration
Write-Host "`n[2/6] Checking configuration..." -ForegroundColor Yellow
$skipConfig = $false
if (Test-Path $envFile) {
    Write-Host "      ⚠ .env file already exists" -ForegroundColor Yellow
    $overwrite = Read-Host "      Do you want to reconfigure? (y/N)"
    if ($overwrite -ne 'y' -and $overwrite -ne 'Y') {
        Write-Host "      Keeping existing configuration" -ForegroundColor Gray
        $skipConfig = $true
    }
}
#endregion

#region Step 3: Create .env configuration
if (-not $skipConfig) {
    Write-Host "`n[3/6] Setting up configuration..." -ForegroundColor Yellow
    
    # No-IP Credentials
    Write-Host "`n  No-IP Credentials:" -ForegroundColor Cyan
    $username = Read-Host "    Username"
    $password = Read-Host "    Password" -AsSecureString
    $passwordPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [Runtime.InteropServices.Marshal]::SecureStringToBSTR($password)
    )
    $hostname = Read-Host "    Hostname (e.g., myhouse.ddns.net)"
    
    # IP Configuration
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
    
    # Logging Configuration
    Write-Host "`n  Logging:" -ForegroundColor Cyan
    $defaultLogPath = Join-Path $scriptDir "logs"
    $logPath = Read-Host "    Log directory (default: $defaultLogPath)"
    if ([string]::IsNullOrWhiteSpace($logPath)) {
        $logPath = $defaultLogPath
    }
    
    # Notifications
    Write-Host "`n  Notifications:" -ForegroundColor Cyan
    $showNotif = Read-Host "    Enable Windows notifications? (y/N)"
    $notifValue = if ($showNotif -eq 'y' -or $showNotif -eq 'Y') { 'true' } else { 'false' }
    
    # Email Alerts
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
}
else {
    Write-Host "`n[3/6] Skipped configuration" -ForegroundColor Gray
}
#endregion

#region Step 4: Test configuration
Write-Host "`n[4/6] Testing configuration..." -ForegroundColor Yellow

$updateScript = Join-Path $scriptDir "Update-noip.ps1"
if (Test-Path $updateScript) {
    try {
        Write-Host "      Running test update..." -ForegroundColor Cyan
        & $updateScript -ShowNotification
        Write-Host "`n      ✓ Test completed! Check logs above for results." -ForegroundColor Green
    }
    catch {
        Write-Host "      ✗ Test failed: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "      Fix errors before continuing to task creation" -ForegroundColor Yellow
        $SkipTaskCreation = $true
    }
}
else {
    Write-Host "      ⚠ Update-noip.ps1 not found at: $updateScript" -ForegroundColor Yellow
    $SkipTaskCreation = $true
}
#endregion

#region Step 5: Create Scheduled Task
if (-not $SkipTaskCreation) {
    Write-Host "`n[5/6] Creating scheduled task..." -ForegroundColor Yellow
    $createTaskScript = Join-Path $scriptDir "CreateTask.ps1"
    if (Test-Path $createTaskScript) {
        try {
            Write-Host "      Running Create Task Script..." -ForegroundColor Cyan
            & $createTaskScript
        }
        catch {
            Write-Host "Something Unexpected Happened!"
        }
    }
    else {
        Write-Host "      ⚠ CreateTask.ps1 not found at: $createTaskScript" -ForegroundColor Yellow
    }
}
else {
    Write-Host "`n[5/6] Skipped task creation" -ForegroundColor Gray
}
#endregion

#region Step 6: Summary
Write-Host "`n[6/6] Setup Complete!" -ForegroundColor Green

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  Setup Summary" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "Configuration file: " -NoNewline -ForegroundColor Yellow
Write-Host $envFile -ForegroundColor White

if (Test-Path $envFile) {
    Write-Host "Task created:       " -NoNewline -ForegroundColor Yellow
    $taskExists = Get-ScheduledTask -TaskName "NoIP_Update_Task" -ErrorAction SilentlyContinue
    if ($taskExists) {
        Write-Host "Yes - NoIP_Update_Task" -ForegroundColor Green
    }
    else {
        Write-Host "No - Create manually with CreateTask.ps1" -ForegroundColor Yellow
    }
}

Write-Host "`nUseful Commands:" -ForegroundColor Yellow
Write-Host "  Monitor task:      " -NoNewline -ForegroundColor Gray
Write-Host ".\Monitor-NoIPTask.ps1" -ForegroundColor White
Write-Host "  View logs:         " -NoNewline -ForegroundColor Gray
Write-Host ".\Monitor-NoIPTask.ps1 -ShowLogs" -ForegroundColor White
Write-Host "  Test manually:     " -NoNewline -ForegroundColor Gray
Write-Host ".\Update-noip.ps1 -ShowNotification" -ForegroundColor White
Write-Host "  Run task now:      " -NoNewline -ForegroundColor Gray
Write-Host "Start-ScheduledTask -TaskName NoIP_Update_Task" -ForegroundColor White
Write-Host "  Reconfigure:       " -NoNewline -ForegroundColor Gray
Write-Host ".\Complete-NoIPSetup.ps1" -ForegroundColor White

Write-Host "`nSecurity Reminders:" -ForegroundColor Red
Write-Host "  • Never commit .env to version control" -ForegroundColor Gray
Write-Host "  • .env permissions restricted to your account" -ForegroundColor Gray
Write-Host "  • Rotate passwords regularly" -ForegroundColor Gray

Write-Host "`n========================================`n" -ForegroundColor Cyan
#endregion
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