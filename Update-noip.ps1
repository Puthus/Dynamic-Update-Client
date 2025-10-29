# No-IP Update Script with .env Support
# Path: D:\media-server\apps\DUC\Update-noip.ps1

param(
    [switch]$ShowNotification
)

# Get script directory
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$envFile = Join-Path $scriptDir ".env"

# Function to load .env file
function Get-EnvConfig {
    param([string]$EnvPath)
    
    if (-not (Test-Path $EnvPath)) {
        throw "Configuration file not found: $EnvPath`nPlease create .env file from .env.example"
    }
    
    $config = @{}
    Get-Content $EnvPath | ForEach-Object {
        $line = $_.Trim()
        # Skip comments and empty lines
        if ($line -and -not $line.StartsWith('#')) {
            if ($line -match '^([^=]+)=(.*)$') {
                $key = $matches[1].Trim()
                $value = $matches[2].Trim()
                # Remove quotes if present
                $value = $value -replace '^["'']|["'']$', ''
                $config[$key] = $value
            }
        }
    }
    return $config
}

# Load configuration
try {
    $config = Get-EnvConfig -EnvPath $envFile
}
catch {
    Write-Error $_.Exception.Message
    exit 1
}

# Extract configuration values
$noipUsername = $config['NOIP_USERNAME']
$noipPassword = $config['NOIP_PASSWORD']
$hostname = $config['NOIP_HOSTNAME']
$logPath = $config['LOG_PATH']
$maxLogSizeMB = [int]$config['MAX_LOG_SIZE_MB']
$showNotifications = if ($ShowNotification) { $true } else { [bool]::Parse($config['SHOW_NOTIFICATIONS']) }
$usePublicIP = [bool]::Parse($config['USE_PUBLIC_IP'])
$networkAdapters = if ($config['NETWORK_ADAPTERS']) { $config['NETWORK_ADAPTERS'] -split ',' | ForEach-Object { $_.Trim() } } else { @('Wi-Fi', 'Ethernet') }

# Validate required fields
$requiredFields = @('NOIP_USERNAME', 'NOIP_PASSWORD', 'NOIP_HOSTNAME', 'LOG_PATH')
foreach ($field in $requiredFields) {
    if ([string]::IsNullOrWhiteSpace($config[$field])) {
        Write-Error "Missing required configuration: $field in .env file"
        exit 1
    }
}

$logFile = Join-Path $logPath "noip-update.log"

# Create log directory if it doesn't exist
if (-not (Test-Path $logPath)) {
    New-Item -ItemType Directory -Path $logPath -Force | Out-Null
}

# Function to write log entries
function Write-Log {
    param(
        [string]$Message,
        [ValidateSet('INFO','SUCCESS','WARNING','ERROR')]
        [string]$Level = 'INFO'
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    
    # Write to log file
    Add-Content -Path $logFile -Value $logEntry
    
    # Also write to console for manual testing
    $color = switch($Level) {
        'SUCCESS' { 'Green' }
        'WARNING' { 'Yellow' }
        'ERROR' { 'Red' }
        default { 'White' }
    }
    Write-Host $logEntry -ForegroundColor $color
}

# Function to rotate log if too large
function Rotate-Log {
    if (Test-Path $logFile) {
        $logSize = (Get-Item $logFile).Length / 1MB
        if ($logSize -gt $maxLogSizeMB) {
            $archiveName = "noip-update_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
            Move-Item $logFile (Join-Path $logPath $archiveName)
            Write-Log "Log rotated to $archiveName" -Level INFO
        }
    }
}

# Function to show Windows notification
function Show-Notification {
    param(
        [string]$Title,
        [string]$Message,
        [ValidateSet('Info','Warning','Error')]
        [string]$Type = 'Info'
    )
    
    if ($showNotifications) {
        try {
            Add-Type -AssemblyName System.Windows.Forms
            $notification = New-Object System.Windows.Forms.NotifyIcon
            $notification.Icon = [System.Drawing.SystemIcons]::Information
            $notification.BalloonTipIcon = $Type
            $notification.BalloonTipText = $Message
            $notification.BalloonTipTitle = $Title
            $notification.Visible = $true
            $notification.ShowBalloonTip(5000)
            Start-Sleep -Seconds 2
            $notification.Dispose()
        }
        catch {
            Write-Log "Failed to show notification: $($_.Exception.Message)" -Level WARNING
        }
    }
}

# Function to send email alert
function Send-EmailAlert {
    param(
        [string]$Subject,
        [string]$Body
    )
    
    # Check if email is configured
    $smtpServer = $config['SMTP_SERVER']
    if ([string]::IsNullOrWhiteSpace($smtpServer)) {
        return  # Email not configured, skip
    }
    
    try {
        $smtpPort = [int]$config['SMTP_PORT']
        $from = $config['EMAIL_FROM']
        $to = $config['EMAIL_TO']
        $password = $config['EMAIL_PASSWORD']
        
        $credential = New-Object System.Management.Automation.PSCredential(
            $from,
            (ConvertTo-SecureString $password -AsPlainText -Force)
        )
        
        Send-MailMessage -From $from -To $to -Subject $Subject -Body $Body `
            -SmtpServer $smtpServer -Port $smtpPort -UseSsl -Credential $credential `
            -ErrorAction Stop
        
        Write-Log "Email alert sent successfully" -Level INFO
    }
    catch {
        Write-Log "Failed to send email alert: $($_.Exception.Message)" -Level WARNING
    }
}

# Main script
try {
    Rotate-Log
    Write-Log "=== No-IP Update Started ===" -Level INFO
    Write-Log "IP Mode: $(if ($usePublicIP) { 'Public (WAN)' } else { 'Local (LAN)' })" -Level INFO
    
    # Get current IP address
    if ($usePublicIP) {
        # Get public WAN IP
        try {
            $currentIP = (Invoke-RestMethod -Uri "https://api.ipify.org" -TimeoutSec 10).Trim()
            Write-Log "Current public IP: $currentIP" -Level INFO
        }
        catch {
            $errorMsg = "Failed to retrieve public IP: $($_.Exception.Message)"
            Write-Log $errorMsg -Level ERROR
            Show-Notification "No-IP Update Failed" "Could not retrieve public IP" "Error"
            Send-EmailAlert "No-IP Update Failed" $errorMsg
            exit 1
        }
    }
    else {
        # Get local LAN IP from specified adapters
        try {
            Write-Log "Checking adapters: $($networkAdapters -join ', ')" -Level INFO
            
            $currentIP = (Get-NetIPAddress -AddressFamily IPv4 -ErrorAction Stop |
                Where-Object {
                    $_.InterfaceAlias -in $networkAdapters -and
                    $_.IPAddress -notlike "169.*" -and
                    $_.AddressState -eq "Preferred"
                } |
                Sort-Object InterfaceMetric |
                Select-Object -First 1 -ExpandProperty IPAddress)
            
            if (-not $currentIP) {
                $errorMsg = "No valid IPv4 found for adapters: $($networkAdapters -join ', ')"
                Write-Log $errorMsg -Level ERROR
                Show-Notification "No-IP Update Failed" "No valid local IP found" "Error"
                Send-EmailAlert "No-IP Update Failed" $errorMsg
                exit 1
            }
            
            Write-Log "Current local IP: $currentIP" -Level INFO
        }
        catch {
            $errorMsg = "Failed to retrieve local IP: $($_.Exception.Message)"
            Write-Log $errorMsg -Level ERROR
            Show-Notification "No-IP Update Failed" "Could not retrieve local IP" "Error"
            Send-EmailAlert "No-IP Update Failed" $errorMsg
            exit 1
        }
    }
    
    # Update No-IP
    $base64Auth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("${noipUsername}:${noipPassword}"))
    $headers = @{
        "Authorization" = "Basic $base64Auth"
        "User-Agent" = "PowerShell No-IP Updater/1.0"
    }
    
    $updateUrl = "https://dynupdate.no-ip.com/nic/update?hostname=$hostname&myip=$currentIP"
    
    try {
        $response = Invoke-WebRequest -Uri $updateUrl -Headers $headers -TimeoutSec 30 -UseBasicParsing
        $responseText = $response.Content.Trim()
        
        Write-Log "No-IP Response: $responseText" -Level INFO
        
        # Parse response
        if ($responseText -match "^good|^nochg") {
            $successMsg = if ($responseText -match "^good") {
                "IP updated to $currentIP"
            } else {
                "IP unchanged ($currentIP)"
            }
            Write-Log "Update successful! $successMsg" -Level SUCCESS
            Show-Notification "No-IP Updated" $successMsg "Info"
        }
        elseif ($responseText -match "^nohost") {
            $errorMsg = "ERROR: Hostname '$hostname' doesn't exist"
            Write-Log $errorMsg -Level ERROR
            Show-Notification "No-IP Error" "Hostname not found" "Error"
            Send-EmailAlert "No-IP Configuration Error" $errorMsg
        }
        elseif ($responseText -match "^badauth") {
            $errorMsg = "ERROR: Invalid credentials for user '$noipUsername'"
            Write-Log $errorMsg -Level ERROR
            Show-Notification "No-IP Error" "Authentication failed" "Error"
            Send-EmailAlert "No-IP Authentication Error" $errorMsg
        }
        elseif ($responseText -match "^abuse") {
            $errorMsg = "ERROR: Hostname '$hostname' blocked for abuse"
            Write-Log $errorMsg -Level ERROR
            Show-Notification "No-IP Error" "Hostname blocked" "Error"
            Send-EmailAlert "No-IP Hostname Blocked" $errorMsg
        }
        elseif ($responseText -match "^911") {
            Write-Log "WARNING: No-IP system issue, will retry later" -Level WARNING
        }
        else {
            $errorMsg = "WARNING: Unexpected response: $responseText"
            Write-Log $errorMsg -Level WARNING
            Show-Notification "No-IP Warning" "Unexpected response" "Warning"
        }
    }
    catch {
        $errorMsg = "Failed to update No-IP: $($_.Exception.Message)"
        Write-Log $errorMsg -Level ERROR
        Show-Notification "No-IP Update Failed" "Network error occurred" "Error"
        Send-EmailAlert "No-IP Update Failed" $errorMsg
        exit 1
    }
}
catch {
    $errorMsg = "Unexpected error: $($_.Exception.Message)"
    Write-Log $errorMsg -Level ERROR
    Show-Notification "No-IP Error" "Unexpected error occurred" "Error"
    Send-EmailAlert "No-IP Unexpected Error" $errorMsg
    exit 1
}
finally {
    Write-Log "=== No-IP Update Completed ===" -Level INFO
}