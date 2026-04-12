param(
    [string]$LogFile = 'target\quarkus.log',
    [int]$Tail = 100,
    [string]$Pattern = 'ERROR|WARN|Exception|Caused by',
    [switch]$JsonOutput
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not (Test-Path $LogFile)) {
    $missing = [pscustomobject]@{
        found = $false
        logFile = [System.IO.Path]::GetFullPath($LogFile)
        rootCause = $null
        excerpt = @()
    }

    if ($JsonOutput) {
        $missing | ConvertTo-Json -Depth 10
    } else {
        $missing
    }
    exit 2
}

$lines = @(Get-Content $LogFile -Tail $Tail)
$filtered = @($lines | Where-Object { $_ -match $Pattern })
$rootCause = $null

foreach ($line in ($filtered | Select-Object -Reverse)) {
    if ($line -match 'Caused by:') {
        $rootCause = $line.Trim()
        break
    }
}

if (-not $rootCause) {
    foreach ($line in ($filtered | Select-Object -Reverse)) {
        if ($line -match 'Exception|ERROR') {
            $rootCause = $line.Trim()
            break
        }
    }
}

$result = [pscustomobject]@{
    found = $true
    logFile = [System.IO.Path]::GetFullPath($LogFile)
    rootCause = $rootCause
    excerpt = $filtered
}

if ($JsonOutput) {
    $result | ConvertTo-Json -Depth 10
} else {
    $result
}