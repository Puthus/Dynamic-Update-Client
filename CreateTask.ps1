# Path to your No-IP update script
$scriptPath = "D:\media-server\apps\DUC\Update-noip.ps1"

# Task settings
$taskName = "NoIP_Update_Task"
$taskDesc = "Updates No-IP hostname every 5 minutes and on network connect"

# Load task helper (optional)
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$helperPath = Join-Path $scriptDir "Lib-TaskHelpers.ps1"
if (Test-Path $helperPath) { . $helperPath } else { Write-Host "Helper not found: $helperPath (continuing without task helper)" -ForegroundColor Yellow }

# Remove existing task if present
if (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue) {
  Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
  Write-Host "Removed existing task." -ForegroundColor Yellow
}

# Create the task using XML
$taskXml = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo>
    <Description>$taskDesc</Description>
    <URI>\$taskName</URI>
  </RegistrationInfo>
  <Triggers>
    <!-- Time-based trigger: Every 5 minutes -->
    <TimeTrigger>
      <Repetition>
        <Interval>PT5M</Interval>
        <StopAtDurationEnd>false</StopAtDurationEnd>
      </Repetition>
      <StartBoundary>$((Get-Date).AddMinutes(1).ToString("yyyy-MM-ddTHH:mm:ss"))</StartBoundary>
      <Enabled>true</Enabled>
    </TimeTrigger>
    
    <!-- NetworkProfile Event: 10000 - Network Profile Connected -->
    <EventTrigger>
      <Enabled>true</Enabled>
      <Subscription>&lt;QueryList&gt;&lt;Query Id="0" Path="Microsoft-Windows-NetworkProfile/Operational"&gt;&lt;Select Path="Microsoft-Windows-NetworkProfile/Operational"&gt;*[System[(EventID=10000)]]&lt;/Select&gt;&lt;/Query&gt;&lt;/QueryList&gt;</Subscription>
    </EventTrigger>
    
    <!-- NetworkProfile Event: 10001 - Network Profile Disconnected -->
    <EventTrigger>
      <Enabled>true</Enabled>
      <Subscription>&lt;QueryList&gt;&lt;Query Id="0" Path="Microsoft-Windows-NetworkProfile/Operational"&gt;&lt;Select Path="Microsoft-Windows-NetworkProfile/Operational"&gt;*[System[(EventID=10001)]]&lt;/Select&gt;&lt;/Query&gt;&lt;/QueryList&gt;</Subscription>
    </EventTrigger>
    
    <!-- NetworkProfile Event: 4001 - Network Connected -->
    <EventTrigger>
      <Enabled>true</Enabled>
      <Subscription>&lt;QueryList&gt;&lt;Query Id="0" Path="Microsoft-Windows-NetworkProfile/Operational"&gt;&lt;Select Path="Microsoft-Windows-NetworkProfile/Operational"&gt;*[System[(EventID=4001)]]&lt;/Select&gt;&lt;/Query&gt;&lt;/QueryList&gt;</Subscription>
    </EventTrigger>
    
    <!-- NetworkProfile Event: 4002 - Network State Transition -->
    <EventTrigger>
      <Enabled>true</Enabled>
      <Subscription>&lt;QueryList&gt;&lt;Query Id="0" Path="Microsoft-Windows-NetworkProfile/Operational"&gt;&lt;Select Path="Microsoft-Windows-NetworkProfile/Operational"&gt;*[System[(EventID=4002)]]&lt;/Select&gt;&lt;/Query&gt;&lt;/QueryList&gt;</Subscription>
    </EventTrigger>
    
    <!-- NetworkProfile Event: 32 - Network Interface Connected -->
    <EventTrigger>
      <Enabled>true</Enabled>
      <Subscription>&lt;QueryList&gt;&lt;Query Id="0" Path="Microsoft-Windows-NetworkProfile/Operational"&gt;&lt;Select Path="Microsoft-Windows-NetworkProfile/Operational"&gt;*[System[(EventID=32)]]&lt;/Select&gt;&lt;/Query&gt;&lt;/QueryList&gt;</Subscription>
    </EventTrigger>
    
    <!-- NetworkProfile Event: 33 - Network Interface Disconnected -->
    <EventTrigger>
      <Enabled>true</Enabled>
      <Subscription>&lt;QueryList&gt;&lt;Query Id="0" Path="Microsoft-Windows-NetworkProfile/Operational"&gt;&lt;Select Path="Microsoft-Windows-NetworkProfile/Operational"&gt;*[System[(EventID=33)]]&lt;/Select&gt;&lt;/Query&gt;&lt;/QueryList&gt;</Subscription>
    </EventTrigger>
    
    <!-- DHCP Event: 50036 - IP Address Lease Obtained -->
    <EventTrigger>
      <Enabled>true</Enabled>
      <Subscription>&lt;QueryList&gt;&lt;Query Id="0" Path="Microsoft-Windows-Dhcp-Client/Operational"&gt;&lt;Select Path="Microsoft-Windows-Dhcp-Client/Operational"&gt;*[System[(EventID=50036)]]&lt;/Select&gt;&lt;/Query&gt;&lt;/QueryList&gt;</Subscription>
    </EventTrigger>
    
    <!-- DHCP Event: 50035 - IP Address Lease Released -->
    <EventTrigger>
      <Enabled>true</Enabled>
      <Subscription>&lt;QueryList&gt;&lt;Query Id="0" Path="Microsoft-Windows-Dhcp-Client/Operational"&gt;&lt;Select Path="Microsoft-Windows-Dhcp-Client/Operational"&gt;*[System[(EventID=50035)]]&lt;/Select&gt;&lt;/Query&gt;&lt;/QueryList&gt;</Subscription>
    </EventTrigger>
    
    <!-- DHCP Event: 1002 - DHCP Configuration Change -->
    <EventTrigger>
      <Enabled>true</Enabled>
      <Subscription>&lt;QueryList&gt;&lt;Query Id="0" Path="Microsoft-Windows-Dhcp-Client/Operational"&gt;&lt;Select Path="Microsoft-Windows-Dhcp-Client/Operational"&gt;*[System[(EventID=1002)]]&lt;/Select&gt;&lt;/Query&gt;&lt;/QueryList&gt;</Subscription>
    </EventTrigger>
    
    <!-- DHCP Event: 1003 - DHCP Configuration Complete -->
    <EventTrigger>
      <Enabled>true</Enabled>
      <Subscription>&lt;QueryList&gt;&lt;Query Id="0" Path="Microsoft-Windows-Dhcp-Client/Operational"&gt;&lt;Select Path="Microsoft-Windows-Dhcp-Client/Operational"&gt;*[System[(EventID=1003)]]&lt;/Select&gt;&lt;/Query&gt;&lt;/QueryList&gt;</Subscription>
    </EventTrigger>
    
    <!-- TCPIP Event: 4201 - IP Address Added -->
    <EventTrigger>
      <Enabled>true</Enabled>
      <Subscription>&lt;QueryList&gt;&lt;Query Id="0" Path="Microsoft-Windows-Tcpip/Operational"&gt;&lt;Select Path="Microsoft-Windows-Tcpip/Operational"&gt;*[System[(EventID=4201)]]&lt;/Select&gt;&lt;/Query&gt;&lt;/QueryList&gt;</Subscription>
    </EventTrigger>
    
    <!-- TCPIP Event: 4202 - IP Address Removed -->
    <EventTrigger>
      <Enabled>true</Enabled>
      <Subscription>&lt;QueryList&gt;&lt;Query Id="0" Path="Microsoft-Windows-Tcpip/Operational"&gt;&lt;Select Path="Microsoft-Windows-Tcpip/Operational"&gt;*[System[(EventID=4202)]]&lt;/Select&gt;&lt;/Query&gt;&lt;/QueryList&gt;</Subscription>
    </EventTrigger>
    
    <!-- WLAN Event: 8001 - WiFi Connected -->
    <EventTrigger>
      <Enabled>true</Enabled>
      <Subscription>&lt;QueryList&gt;&lt;Query Id="0" Path="Microsoft-Windows-WLAN-AutoConfig/Operational"&gt;&lt;Select Path="Microsoft-Windows-WLAN-AutoConfig/Operational"&gt;*[System[(EventID=8001)]]&lt;/Select&gt;&lt;/Query&gt;&lt;/QueryList&gt;</Subscription>
    </EventTrigger>
    
    <!-- WLAN Event: 8002 - WiFi Connection Failed -->
    <EventTrigger>
      <Enabled>true</Enabled>
      <Subscription>&lt;QueryList&gt;&lt;Query Id="0" Path="Microsoft-Windows-WLAN-AutoConfig/Operational"&gt;&lt;Select Path="Microsoft-Windows-WLAN-AutoConfig/Operational"&gt;*[System[(EventID=8002)]]&lt;/Select&gt;&lt;/Query&gt;&lt;/QueryList&gt;</Subscription>
    </EventTrigger>
    
    <!-- WLAN Event: 8003 - WiFi Disconnected -->
    <EventTrigger>
      <Enabled>true</Enabled>
      <Subscription>&lt;QueryList&gt;&lt;Query Id="0" Path="Microsoft-Windows-WLAN-AutoConfig/Operational"&gt;&lt;Select Path="Microsoft-Windows-WLAN-AutoConfig/Operational"&gt;*[System[(EventID=8003)]]&lt;/Select&gt;&lt;/Query&gt;&lt;/QueryList&gt;</Subscription>
    </EventTrigger>
    
    <!-- WLAN Event: 11000 - WiFi Authentication Started -->
    <EventTrigger>
      <Enabled>true</Enabled>
      <Subscription>&lt;QueryList&gt;&lt;Query Id="0" Path="Microsoft-Windows-WLAN-AutoConfig/Operational"&gt;&lt;Select Path="Microsoft-Windows-WLAN-AutoConfig/Operational"&gt;*[System[(EventID=11000)]]&lt;/Select&gt;&lt;/Query&gt;&lt;/QueryList&gt;</Subscription>
    </EventTrigger>
    
    <!-- WLAN Event: 12011 - WiFi Roaming Started -->
    <EventTrigger>
      <Enabled>true</Enabled>
      <Subscription>&lt;QueryList&gt;&lt;Query Id="0" Path="Microsoft-Windows-WLAN-AutoConfig/Operational"&gt;&lt;Select Path="Microsoft-Windows-WLAN-AutoConfig/Operational"&gt;*[System[(EventID=12011)]]&lt;/Select&gt;&lt;/Query&gt;&lt;/QueryList&gt;</Subscription>
    </EventTrigger>
    
    <!-- WLAN Event: 12012 - WiFi Roaming Complete -->
    <EventTrigger>
      <Enabled>true</Enabled>
      <Subscription>&lt;QueryList&gt;&lt;Query Id="0" Path="Microsoft-Windows-WLAN-AutoConfig/Operational"&gt;&lt;Select Path="Microsoft-Windows-WLAN-AutoConfig/Operational"&gt;*[System[(EventID=12012)]]&lt;/Select&gt;&lt;/Query&gt;&lt;/QueryList&gt;</Subscription>
    </EventTrigger>
    
    <!-- Boot trigger as backup -->
    <BootTrigger>
      <Enabled>true</Enabled>
    </BootTrigger>
  </Triggers>
  <Principals>
    <Principal id="Author">
      <UserId>$env:USERDOMAIN\$env:USERNAME</UserId>
      <LogonType>S4U</LogonType>
      <RunLevel>HighestAvailable</RunLevel>
    </Principal>
  </Principals>
  <Settings>
    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
    <AllowHardTerminate>true</AllowHardTerminate>
    <StartWhenAvailable>true</StartWhenAvailable>
    <RunOnlyIfNetworkAvailable>false</RunOnlyIfNetworkAvailable>
    <IdleSettings>
      <StopOnIdleEnd>false</StopOnIdleEnd>
      <RestartOnIdle>false</RestartOnIdle>
    </IdleSettings>
    <AllowStartOnDemand>true</AllowStartOnDemand>
    <Enabled>true</Enabled>
    <Hidden>false</Hidden>
    <RunOnlyIfIdle>false</RunOnlyIfIdle>
    <WakeToRun>false</WakeToRun>
    <ExecutionTimeLimit>PT1H</ExecutionTimeLimit>
    <Priority>7</Priority>
  </Settings>
  <Actions Context="Author">
    <Exec>
      <Command>powershell.exe</Command>
      <Arguments>-ExecutionPolicy Bypass -WindowStyle Hidden -File "$scriptPath"</Arguments>
    </Exec>
  </Actions>
</Task>
"@

# Register the task with error handling
try {
  Register-ScheduledTask -TaskName $taskName -Xml $taskXml -ErrorAction Stop | Out-Null
  Write-Host "      ✓ Task '$taskName' created successfully!" -ForegroundColor Green
    
  $task = Get-ScheduledTask -TaskName $taskName
  Write-Host "`n      Task Configuration:" -ForegroundColor Cyan
  Write-Host "        State:    " -NoNewline
  Write-Host $task.State -ForegroundColor $(if ($task.State -eq 'Ready') { 'Green' } else { 'Yellow' })
  Write-Host "        Triggers: $($task.Triggers.Count) total (20 events + time + boot)" -ForegroundColor White
  Write-Host "          - Every 5 minutes" -ForegroundColor Gray
  Write-Host "          - NetworkProfile: 10000,10001,4001,4002,32,33" -ForegroundColor Gray
  Write-Host "          - DHCP Client: 50036,50035,1002,1003" -ForegroundColor Gray
  Write-Host "          - TCP/IP: 4201,4202" -ForegroundColor Gray
  Write-Host "          - WLAN: 8001,8002,8003,11000,12011,12012" -ForegroundColor Gray
  Write-Host "          - System boot" -ForegroundColor Gray
    
  # Run initial update
  Write-Host "`n      Running initial task..." -ForegroundColor Cyan
  Start-ScheduledTask -TaskName $taskName
  Start-Sleep -Seconds 3
    
  $taskInfo = Get-ScheduledTaskInfo -TaskName $taskName
  $resultCode = $taskInfo.LastTaskResult

  if ($resultCode -eq 0) {
    Write-Host "      ✓ Initial run successful!" -ForegroundColor Green
  }
  else {
    if (Get-Command -Name Get-TaskResultDescription -ErrorAction SilentlyContinue) {
      $desc = Get-TaskResultDescription -ResultCode $resultCode
      Write-Host "      ⚠ Task result: $desc" -ForegroundColor Yellow
    }
    else {
      Write-Host "      ⚠ Task result code: 0x$($resultCode.ToString('X'))" -ForegroundColor Yellow
    }
  }
}
catch {
  Write-Host "      ✗ Failed to create task: $($_.Exception.Message)" -ForegroundColor Red
  Write-Host "`n      Attempting fallback configuration..." -ForegroundColor Yellow
    
  try {
    $trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) `
      -RepetitionInterval (New-TimeSpan -Minutes 5)
        
    $action = New-ScheduledTaskAction -Execute "powershell.exe" `
      -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$ScriptPath`""
        
    $principal = New-ScheduledTaskPrincipal -UserId "$env:USERNAME" `
      -LogonType S4U -RunLevel Highest
        
    $settings = New-ScheduledTaskSettingsSet -MultipleInstances IgnoreNew `
      -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
        
    Register-ScheduledTask -TaskName $taskName `
      -Action $action -Trigger $trigger -Principal $principal `
      -Settings $settings -Description $taskDesc | Out-Null
        
    Write-Host "      ✓ Task created with time-based trigger only" -ForegroundColor Green
    Write-Host "      ℹ Add network triggers manually in Task Scheduler if needed" -ForegroundColor Gray
  }
  catch {
    Write-Host "      ✗ Fallback failed: $($_.Exception.Message)" -ForegroundColor Red
  }
}