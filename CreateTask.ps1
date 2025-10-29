# Path to your No-IP update script
$scriptPath = "D:\media-server\apps\DUC\Update-noip.ps1"

# Task settings
$taskName   = "NoIP_Update_Task"
$taskDesc   = "Updates No-IP hostname every 5 minutes and on network connect"

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
  </RegistrationInfo>
  <Triggers>
    <TimeTrigger>
      <Repetition>
        <Interval>PT5M</Interval>
        <StopAtDurationEnd>false</StopAtDurationEnd>
      </Repetition>
      <StartBoundary>$((Get-Date).AddMinutes(1).ToString("yyyy-MM-ddTHH:mm:ss"))</StartBoundary>
      <Enabled>true</Enabled>
    </TimeTrigger>
    <EventTrigger>
      <Enabled>true</Enabled>
      <Subscription>&lt;QueryList&gt;&lt;Query Id="0" Path="Microsoft-Windows-NetworkProfile/Operational"&gt;&lt;Select Path="Microsoft-Windows-NetworkProfile/Operational"&gt;*[System[Provider[@Name='Microsoft-Windows-NetworkProfile'] and EventID=10000]]&lt;/Select&gt;&lt;/Query&gt;&lt;/QueryList&gt;</Subscription>
    </EventTrigger>
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
    Register-ScheduledTask -TaskName $taskName -Xml $taskXml -ErrorAction Stop
    Write-Host "✅ Task '$taskName' created successfully!" -ForegroundColor Green
    
    # Verify it was created
    $task = Get-ScheduledTask -TaskName $taskName -ErrorAction Stop
    Write-Host "   - Runs every 5 minutes" -ForegroundColor Cyan
    Write-Host "   - Runs on network connection (Event ID 10000)" -ForegroundColor Cyan
    Write-Host "   - Triggers: $($task.Triggers.Count)" -ForegroundColor Cyan
}
catch {
    Write-Host "❌ Error creating task: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Attempting simpler approach..." -ForegroundColor Yellow
    
    # Fallback: Create without network trigger first
    $trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) `
        -RepetitionInterval (New-TimeSpan -Minutes 5)
    
    $action = New-ScheduledTaskAction -Execute "powershell.exe" `
        -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$scriptPath`""
    
    $principal = New-ScheduledTaskPrincipal -UserId "$env:USERNAME" `
        -LogonType S4U -RunLevel Highest
    
    Register-ScheduledTask -TaskName $taskName `
        -Action $action `
        -Trigger $trigger `
        -Principal $principal `
        -Description $taskDesc
    
    Write-Host "✅ Task created with 5-minute trigger only" -ForegroundColor Green
    Write-Host "   To add network trigger, use Task Scheduler GUI:" -ForegroundColor Yellow
    Write-Host "   1. Open Task Scheduler" -ForegroundColor Gray
    Write-Host "   2. Find '$taskName'" -ForegroundColor Gray
    Write-Host "   3. Add trigger: On an event > Log: Microsoft-Windows-NetworkProfile/Operational > Event ID: 10000" -ForegroundColor Gray
}