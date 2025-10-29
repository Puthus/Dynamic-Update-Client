# No-IP Dynamic DNS Updater

Automated PowerShell script to keep your No-IP hostname updated with your current IP address.

## Features

- ✅ **Dual IP Mode**: Update with Public (WAN) or Local (LAN) IP
- ✅ **Secure Configuration**: Credentials stored in `.env` file
- ✅ **Detailed Logging**: Track all updates with timestamps
- ✅ **Windows Notifications**: Optional desktop alerts
- ✅ **Email Alerts**: Optional error notifications
- ✅ **Multiple Triggers**: Time-based (5 min) + 6 network event triggers
- ✅ **Monitoring Tools**: Easy status checking + network event diagnostics

## Quick Start

### 1. Initial Setup

```powershell
# Run the setup wizard
.\Setup-NoIP.ps1
```

The wizard will ask you:
- No-IP credentials (username, password, hostname)
- **IP Mode**: Public (WAN) vs Local (LAN)
- Notification preferences
- Optional email alerts

### 2. Create Scheduled Task

```powershell
# Create Windows Task Scheduler task
.\CreateTask.ps1
```

### 3. Monitor

```powershell
# Check task status and logs
.\Monitor-NoIPTask.ps1
```

## IP Mode Configuration

### Public IP Mode (WAN)
**Use Case**: Update with your external/public IP for remote access from internet

```env
USE_PUBLIC_IP=true
```

- Retrieves IP from `https://api.ipify.org`
- Perfect for: Remote desktop, home servers, VPN access
- Example: `203.0.113.45`

### Local IP Mode (LAN)
**Use Case**: Update with your internal network IP for local network access

```env
USE_PUBLIC_IP=false
NETWORK_ADAPTERS=Wi-Fi,Ethernet
```

- Retrieves IP from specified network adapters
- Perfect for: Internal DNS, local services, network management
- Example: `192.168.1.100`
- Automatically excludes APIPA addresses (169.254.x.x)

## Configuration (.env)

After running `Setup-NoIP.ps1`, edit `.env` to change settings:

```env
# Credentials
NOIP_USERNAME=your-email@example.com
NOIP_PASSWORD=your-password
NOIP_HOSTNAME=myhouse.ddns.net

# IP Mode
USE_PUBLIC_IP=true                    # true = WAN, false = LAN
NETWORK_ADAPTERS=Wi-Fi,Ethernet       # Used when USE_PUBLIC_IP=false

# Logging
LOG_PATH=D:\media-server\apps\DUC\logs
MAX_LOG_SIZE_MB=10

# Notifications
SHOW_NOTIFICATIONS=true

# Email Alerts (optional)
SMTP_SERVER=smtp.gmail.com
SMTP_PORT=587
EMAIL_FROM=alerts@gmail.com
EMAIL_TO=your-email@gmail.com
EMAIL_PASSWORD=your-app-password
```

## Monitoring Commands

```powershell
# View task status and recent logs
.\Monitor-NoIPTask.ps1

# View last 50 log entries
.\Monitor-NoIPTask.ps1 -ShowLogs -TailLines 50

# View last complete run details
.\Monitor-NoIPTask.ps1 -LastRun

# Test run manually with notifications
.\Monitor-NoIPTask.ps1 -TestRun

# Live log monitoring (real-time)
Get-Content ".\logs\noip-update.log" -Wait -Tail 20
```

## File Structure

```
D:\media-server\apps\DUC\
├── .env                    # Your credentials (NEVER commit!)
├── .env.example            # Template (safe to commit)
├── .gitignore              # Protects sensitive files
├── Update-noip.ps1         # Main update script
├── CreateTask.ps1          # Task creation script
├── Monitor-NoIPTask.ps1    # Monitoring script
├── Setup-NoIP.ps1          # Initial setup helper
├── README.md               # This file
└── logs/                   # Log files
    └── noip-update.log
```

## Troubleshooting

### Identify Network Events on Your System

Use the diagnostic tool to see which events fire when you switch networks:

```powershell
# Run this, then switch from Wi-Fi to Ethernet
.\Monitor-NetworkEvents.ps1

# Monitor for longer period
.\Monitor-NetworkEvents.ps1 -Seconds 120

# See ALL network events (verbose)
.\Monitor-NetworkEvents.ps1 -ShowAll
```

This will show you exactly which Event IDs trigger on your system when you change networks.

### Task Not Running on Network Switch

The task includes 6 different network event triggers:
1. **Event ID 10000** - Network Profile Connected
2. **Event ID 4001** - Network Connected
3. **Event ID 50036** - DHCP IP Assigned
4. **Event ID 32** - Network Interface Connected
5. **At Startup** - Backup trigger
6. **Every 5 minutes** - Fallback timer

If switching networks doesn't trigger the task:
1. Run `.\Monitor-NetworkEvents.ps1` to identify which events fire on your system
2. Manually add those Event IDs to the task in Task Scheduler
3. The 5-minute timer ensures updates happen regardless

```powershell
# Check task status
Get-ScheduledTask -TaskName "NoIP_Update_Task"

# View task history
Get-WinEvent -FilterHashtable @{
    LogName='Microsoft-Windows-TaskScheduler/Operational'
    ID=201
} -MaxEvents 10
```

### No Valid Local IP Found

If using Local IP mode and seeing errors:
1. Check adapter names: `Get-NetAdapter | Select Name, Status`
2. Update `NETWORK_ADAPTERS` in `.env` with correct names
3. Verify adapter has valid IP: `Get-NetIPAddress -InterfaceAlias "Wi-Fi"`

### Authentication Failures

- Verify credentials in `.env` are correct
- Check No-IP account status at https://www.noip.com
- Ensure hostname exists in your No-IP account

### Task Scheduler Result Codes

Common codes you might see:

- `0x0` - ✅ Success
- `0x41301` - ⏳ Task is currently running (not an error!)
- `0x41303` - ⚠️ Task has not yet run
- `0x41306` - Task was terminated by user
- `0x8004131F` - Another instance is already running
- `0x1` - Script file not found or execution error

To see detailed error info, check the logs:
```powershell
.\Monitor-NoIPTask.ps1 -LastRun
```

## Security Notes

- ⚠️ **Never commit `.env` to version control**
- ⚠️ `.env` permissions are restricted to current user only
- ⚠️ Rotate passwords regularly
- ⚠️ Use app-specific passwords for email alerts (Gmail)

## No-IP Response Codes

The script handles these No-IP API responses:

- `good` - Update successful
- `nochg` - IP unchanged (no update needed)
- `nohost` - Hostname doesn't exist
- `badauth` - Invalid credentials
- `abuse` - Hostname blocked
- `911` - System issue (retry later)

## License

This is a utility script for personal use with No-IP Dynamic DNS service.

## Support

For issues:
1. Check logs: `.\Monitor-NoIPTask.ps1 -ShowLogs`
2. Test manually: `.\Update-noip.ps1 -ShowNotification`
3. Verify No-IP account status
4. Check network connectivity
