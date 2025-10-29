# Network Event Monitor
# Use this to discover which events fire when you switch networks
# Run this, then switch from Wi-Fi to Ethernet (or vice versa) to see what triggers

param(
    [int]$Seconds = 60,
    [switch]$ShowAll
)

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  Network Event Monitor" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "Monitoring network events for $Seconds seconds..." -ForegroundColor Yellow
Write-Host "Now switch from Wi-Fi to Ethernet (or vice versa)...`n" -ForegroundColor Yellow

$startTime = Get-Date

# Define event sources to monitor
$eventSources = @(
    @{
        Name = "NetworkProfile"
        Log = "Microsoft-Windows-NetworkProfile/Operational"
        IDs = @(10000, 10001, 4001, 4002, 32, 33)
    },
    @{
        Name = "DHCP Client"
        Log = "Microsoft-Windows-Dhcp-Client/Operational"
        IDs = @(50036, 50035, 1002, 1003)
    },
    @{
        Name = "TCPIP"
        Log = "Microsoft-Windows-Tcpip/Operational"
        IDs = @(4201, 4202)
    },
    @{
        Name = "WLAN-AutoConfig"
        Log = "Microsoft-Windows-WLAN-AutoConfig/Operational"
        IDs = @(8001, 8002, 8003, 11000, 12011, 12012)
    }
)

$allEvents = @()

foreach ($source in $eventSources) {
    try {
        Write-Host "Checking $($source.Name)..." -ForegroundColor Gray
        
        $filter = @{
            LogName = $source.Log
            StartTime = $startTime
        }
        
        if (-not $ShowAll) {
            $filter['ID'] = $source.IDs
        }
        
        $events = Get-WinEvent -FilterHashtable $filter -ErrorAction SilentlyContinue |
            Where-Object { $_.TimeCreated -ge $startTime }
        
        if ($events) {
            $allEvents += $events | Select-Object TimeCreated, 
                @{N='Source';E={$source.Name}},
                Id, 
                LevelDisplayName, 
                Message
        }
    }
    catch {
        # Log not available or no events
    }
}

# Monitor for specified duration
$endTime = $startTime.AddSeconds($Seconds)
Write-Host "`nMonitoring started at: $($startTime.ToString('HH:mm:ss'))" -ForegroundColor Cyan
Write-Host "Will stop at: $($endTime.ToString('HH:mm:ss'))" -ForegroundColor Cyan
Write-Host "`nWaiting for network changes..." -ForegroundColor Yellow

while ((Get-Date) -lt $endTime) {
    Start-Sleep -Seconds 2
    
    # Check for new events
    foreach ($source in $eventSources) {
        try {
            $filter = @{
                LogName = $source.Log
                StartTime = $startTime
            }
            
            if (-not $ShowAll) {
                $filter['ID'] = $source.IDs
            }
            
            $newEvents = Get-WinEvent -FilterHashtable $filter -ErrorAction SilentlyContinue |
                Where-Object { $_.TimeCreated -ge $startTime -and $_.TimeCreated -notin $allEvents.TimeCreated }
            
            foreach ($event in $newEvents) {
                $eventObj = $event | Select-Object TimeCreated,
                    @{N='Source';E={$source.Name}},
                    Id,
                    LevelDisplayName,
                    Message
                
                $allEvents += $eventObj
                
                # Display immediately
                Write-Host "`n[$(Get-Date -Format 'HH:mm:ss')] " -NoNewline -ForegroundColor Green
                Write-Host "NEW EVENT DETECTED!" -ForegroundColor Yellow
                Write-Host "  Source:  " -NoNewline -ForegroundColor Gray
                Write-Host $eventObj.Source -ForegroundColor White
                Write-Host "  Event ID:" -NoNewline -ForegroundColor Gray
                Write-Host " $($eventObj.Id)" -ForegroundColor Cyan
                Write-Host "  Level:   " -NoNewline -ForegroundColor Gray
                Write-Host $eventObj.LevelDisplayName -ForegroundColor White
                Write-Host "  Message: " -NoNewline -ForegroundColor Gray
                Write-Host $eventObj.Message.Split("`n")[0] -ForegroundColor White
            }
        }
        catch {
            # Ignore
        }
    }
    
    # Show countdown
    $remaining = ($endTime - (Get-Date)).TotalSeconds
    Write-Host "`rTime remaining: $([int]$remaining) seconds " -NoNewline -ForegroundColor Gray
}

Write-Host "`n`n========================================" -ForegroundColor Cyan
Write-Host "  Monitoring Complete!" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

if ($allEvents.Count -eq 0) {
    Write-Host "No network events detected during monitoring period." -ForegroundColor Yellow
    Write-Host "`nTry:" -ForegroundColor Yellow
    Write-Host "  1. Disconnecting/reconnecting network" -ForegroundColor Gray
    Write-Host "  2. Switching between Wi-Fi and Ethernet" -ForegroundColor Gray
    Write-Host "  3. Running with -ShowAll flag to see all events" -ForegroundColor Gray
    Write-Host "  4. Increasing duration: -Seconds 120" -ForegroundColor Gray
} else {
    Write-Host "Detected $($allEvents.Count) network events:`n" -ForegroundColor Green
    
    # Group by Event ID
    $grouped = $allEvents | Group-Object Id | Sort-Object Count -Descending
    
    Write-Host "Event Summary:" -ForegroundColor Yellow
    foreach ($group in $grouped) {
        Write-Host "  Event ID $($group.Name): " -NoNewline -ForegroundColor Cyan
        Write-Host "$($group.Count) occurrence(s) " -NoNewline -ForegroundColor White
        Write-Host "[$($group.Group[0].Source)]" -ForegroundColor Gray
    }
    
    Write-Host "`nRecommended Event IDs for triggers:" -ForegroundColor Yellow
    $recommended = $grouped | Where-Object { $_.Count -ge 2 } | Select-Object -First 3
    
    if ($recommended) {
        foreach ($rec in $recommended) {
            $sample = $rec.Group[0]
            Write-Host "  • Event ID $($rec.Name) " -NoNewline -ForegroundColor Green
            Write-Host "($($sample.Source))" -ForegroundColor Gray
            Write-Host "    Fired $($rec.Count) times - Good candidate!" -ForegroundColor White
        }
    } else {
        Write-Host "  Not enough data. Try switching networks again." -ForegroundColor Gray
    }
    
    # Show detailed events
    Write-Host "`nDetailed Event Log:" -ForegroundColor Yellow
    $allEvents | Sort-Object TimeCreated | ForEach-Object {
        Write-Host "`n[$($_.TimeCreated.ToString('HH:mm:ss'))] " -NoNewline -ForegroundColor Gray
        Write-Host "Event ID $($_.Id) " -NoNewline -ForegroundColor Cyan
        Write-Host "[$($_.Source)]" -ForegroundColor Gray
        Write-Host "  $($_.Message.Split("`n")[0])" -ForegroundColor White
    }
    
    # Export to file
    $logFile = "network-events-$(Get-Date -Format 'yyyyMMdd-HHmmss').csv"
    $allEvents | Export-Csv -Path $logFile -NoTypeInformation
    Write-Host "`n✅ Full log exported to: $logFile" -ForegroundColor Green
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Common Event IDs:" -ForegroundColor Yellow
Write-Host "  10000 - Network connected" -ForegroundColor Gray
Write-Host "  4001  - Network state change" -ForegroundColor Gray
Write-Host "  50036 - DHCP IP address assigned" -ForegroundColor Gray
Write-Host "  32    - Interface connected" -ForegroundColor Gray
Write-Host "  8001  - WLAN connected" -ForegroundColor Gray
Write-Host "  8003  - WLAN disconnected" -ForegroundColor Gray
Write-Host "`nUsage:" -ForegroundColor Yellow
Write-Host "  .\Monitor-NetworkEvents.ps1              # Monitor for 60s" -ForegroundColor Gray
Write-Host "  .\Monitor-NetworkEvents.ps1 -Seconds 120 # Monitor for 120s" -ForegroundColor Gray
Write-Host "  .\Monitor-NetworkEvents.ps1 -ShowAll     # Show ALL events" -ForegroundColor Gray
Write-Host "========================================`n" -ForegroundColor Cyan