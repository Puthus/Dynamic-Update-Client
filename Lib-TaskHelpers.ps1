<#
Library: Lib-TaskHelpers.ps1
Provides helper functions for Task Scheduler result code descriptions.
#>

function Get-TaskResultDescription {
    param(
        [int]$ResultCode
    )

    $descriptions = @{
        0x0        = "Success"
        0x1        = "Incorrect function called or unknown function called"
        0x2        = "File not found"
        0xA        = "The environment is incorrect"
        0x41300   = "Task is ready to run"
        0x41301   = "Task is currently running"
        0x41302   = "Task is disabled"
        0x41303   = "Task has not yet run"
        0x41304   = "There are no more runs scheduled"
        0x41306   = "Task was terminated by the user"
        0x8004130F = "Credentials became corrupted"
        0x8004131F = "An instance of this task is already running"
        0x800710E0 = "The operator or administrator has refused the request"
    }

    if ($null -eq $ResultCode) { $ResultCode = 0 }
    $hexCode = "0x$($ResultCode.ToString('X'))"

    if ($descriptions.ContainsKey($ResultCode)) {
        return "$hexCode - $($descriptions[$ResultCode])"
    }
    return $hexCode
}

Export-ModuleMember -Function Get-TaskResultDescription
