# No-IP Task Monitor
# Usage: .\Monitor-NoIPTask.ps1 [-ShowLogs] [-LastRun] [-TestRun]

param(
    [switch]$ShowLogs,
    [switch]$LastRun,
    [switch]$TestRun,
    [int]$TailLines = 20
)

$taskName = "NoIP_Update_Task"
$logFile = "D:\media-server\apps\DUC\logs\noip-update.log"

# Load shared task helpers if available (optional)
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$helperPath = Join-Path $scriptDir "Lib-TaskHelpers.ps1"
if (Test-Path $helperPath) { . $helperPath } else { Write-Host "Helper not found: $helperPath (continuing with built-in helper)" -ForegroundColor Yellow }

function Show-TaskStatus {
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "  No-IP Task Status Check" -ForegroundColor Cyan
    Write-Host "========================================`n" -ForegroundColor Cyan
    
    try {
        $task = Get-ScheduledTask -TaskName $taskName -ErrorAction Stop
        $taskInfo = Get-ScheduledTaskInfo -TaskName $taskName
        
        # Task state
        $stateColor = if ($task.State -eq 'Ready') { 'Green' } else { 'Yellow' }
        Write-Host "Task Name:      " -NoNewline
        Write-Host $task.TaskName -ForegroundColor White
        Write-Host "State:          " -NoNewline
        Write-Host $task.State -ForegroundColor $stateColor
        Write-Host "Enabled:        " -NoNewline
        Write-Host $(if ($task.Settings.Enabled) { "Yes" } else { "No" }) -ForegroundColor $(if ($task.Settings.Enabled) { 'Green' } else { 'Red' })
        
        # Last run info
        Write-Host "`nLast Execution:" -ForegroundColor Yellow
        Write-Host "  Time:         " -NoNewline
        if ($taskInfo.LastRunTime -eq (Get-Date "1/1/1900")) {
            Write-Host "Never" -ForegroundColor Gray
        } else {
            Write-Host $taskInfo.LastRunTime -ForegroundColor White
            $timeSince = (Get-Date) - $taskInfo.LastRunTime
            Write-Host "  Time Since:   " -NoNewline
            Write-Host "$([int]$timeSince.TotalMinutes) minutes ago" -ForegroundColor White
        }
        
        Write-Host "  Result Code:  " -NoNewline
        $desc = Get-TaskResultDescription -ResultCode $taskInfo.LastTaskResult
        $resultColor = if ($taskInfo.LastTaskResult -eq 0) { 'Green' } else { 'Yellow' }
        Write-Host $desc -ForegroundColor $resultColor
        
        # Next run
        Write-Host "`nNext Execution:" -ForegroundColor Yellow
        Write-Host "  Time:         " -NoNewline
        Write-Host $taskInfo.NextRunTime -ForegroundColor White
        $timeUntil = $taskInfo.NextRunTime - (Get-Date)
        Write-Host "  Time Until:   " -NoNewline
        Write-Host "$([int]$timeUntil.TotalMinutes) minutes" -ForegroundColor White
        
        # Triggers
        Write-Host "`nTriggers:       " -NoNewline
        Write-Host $task.Triggers.Count -ForegroundColor White
        foreach ($trigger in $task.Triggers) {
            $triggerType = $trigger.CimClass.CimClassName -replace 'MSFT_Task', ''
            Write-Host "  - $triggerType" -ForegroundColor Gray
        }
        
        # Actions
        Write-Host "`nAction:         " -NoNewline
        $action = $task.Actions[0]
        Write-Host "$($action.Execute) $($action.Arguments)" -ForegroundColor Gray
        
    }
    catch {
        Write-Host "❌ Task '$taskName' not found!" -ForegroundColor Red
        Write-Host "Run CreateTask.ps1 to create it." -ForegroundColor Yellow
        return $false
    }
    
    return $true
}

function Show-RecentLogs {
    param([int]$Lines = 20)
    
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "  Recent Log Entries (Last $Lines)" -ForegroundColor Cyan
    Write-Host "========================================`n" -ForegroundColor Cyan
    
    if (Test-Path $logFile) {
        $logs = Get-Content $logFile -Tail $Lines
        foreach ($log in $logs) {
            $color = 'White'
            if ($log -match '\[SUCCESS\]') { $color = 'Green' }
            elseif ($log -match '\[ERROR\]') { $color = 'Red' }
            elseif ($log -match '\[WARNING\]') { $color = 'Yellow' }
            elseif ($log -match '\[INFO\]') { $color = 'Cyan' }
            
            Write-Host $log -ForegroundColor $color
        }
        
        # Log file stats
        $logSize = (Get-Item $logFile).Length / 1KB
        Write-Host "`nLog file size: " -NoNewline -ForegroundColor Gray
        Write-Host "$([math]::Round($logSize, 2)) KB" -ForegroundColor Gray
    }
    else {
        Write-Host "No log file found at: $logFile" -ForegroundColor Yellow
        Write-Host "Task may not have run yet." -ForegroundColor Gray
    }
}

function Show-LastRunDetails {
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "  Last Run Details" -ForegroundColor Cyan
    Write-Host "========================================`n" -ForegroundColor Cyan
    
    if (Test-Path $logFile) {
        # Find the last complete run
        $allLogs = Get-Content $logFile
        $lastStartIndex = $null
        
        for ($i = $allLogs.Count - 1; $i -ge 0; $i--) {
            if ($allLogs[$i] -match "=== No-IP Update Started ===") {
                $lastStartIndex = $i
                break
            }
        }
        
        if ($lastStartIndex) {
            $lastRun = $allLogs[$lastStartIndex..($allLogs.Count - 1)]
            foreach ($line in $lastRun) {
                $color = 'White'
                if ($line -match '\[SUCCESS\]') { $color = 'Green' }
                elseif ($line -match '\[ERROR\]') { $color = 'Red' }
                elseif ($line -match '\[WARNING\]') { $color = 'Yellow' }
                
                Write-Host $line -ForegroundColor $color
            }
        }
        else {
            Write-Host "No complete run found in logs." -ForegroundColor Yellow
        }
    }
    else {
        Write-Host "No log file found." -ForegroundColor Yellow
    }
}

function Test-ManualRun {
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "  Manual Test Run" -ForegroundColor Cyan
    Write-Host "========================================`n" -ForegroundColor Cyan
    
    $scriptPath = "D:\media-server\apps\DUC\Update-noip.ps1"
    
    if (Test-Path $scriptPath) {
        Write-Host "Running script manually with notifications...`n" -ForegroundColor Yellow
        & $scriptPath -ShowNotification
    }
    else {
        Write-Host "Script not found at: $scriptPath" -ForegroundColor Red
    }
}

# Main execution
if ($TestRun) {
    Test-ManualRun
}
elseif ($LastRun) {
    Show-LastRunDetails
}
elseif ($ShowLogs) {
    Show-RecentLogs -Lines $TailLines
}
else {
    # Default: show everything
    $taskExists = Show-TaskStatus
    if ($taskExists) {
        Show-RecentLogs -Lines $TailLines
    }
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Options:" -ForegroundColor Yellow
Write-Host "  -ShowLogs          View recent log entries" -ForegroundColor Gray
Write-Host "  -LastRun           Show last complete run" -ForegroundColor Gray
Write-Host "  -TestRun           Run script manually" -ForegroundColor Gray
Write-Host "  -TailLines <n>     Number of log lines (default: 20)" -ForegroundColor Gray
Write-Host "`nExamples:" -ForegroundColor Yellow
Write-Host "  .\Monitor-NoIPTask.ps1" -ForegroundColor Gray
Write-Host "  .\Monitor-NoIPTask.ps1 -ShowLogs -TailLines 50" -ForegroundColor Gray
Write-Host "  .\Monitor-NoIPTask.ps1 -TestRun" -ForegroundColor Gray
Write-Host "========================================`n" -ForegroundColor Cyan