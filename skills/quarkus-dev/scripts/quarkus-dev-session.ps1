param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('start', 'wait', 'status', 'stop')]
    [string]$Action,

    [Parameter(Mandatory = $true)]
    [string]$ServiceDir,

    [int]$Port = 8080,
    [int]$TimeoutSeconds = 60,
    [string]$HealthPath = '/q/health/ready',
    [string]$MavenWrapper = '.\mvnw.cmd',
    [string]$ExtraArgs = '-Dquarkus.log.file.enable=true -Ddebug=false',
    [string]$PidFileName = '.quarkus-dev.pid.json',
    [string]$ConsoleLog = 'target\quarkus-dev-console.log',
    [string]$ErrorLog = 'target\quarkus-dev-error.log',
    [switch]$JsonOutput
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Result($data) {
    if ($JsonOutput) {
        $data | ConvertTo-Json -Depth 8
    } else {
        $data
    }
}

function Get-AbsolutePath([string]$baseDir, [string]$childPath) {
    return [System.IO.Path]::GetFullPath((Join-Path $baseDir $childPath))
}

function Read-TrackedSession([string]$pidFilePath) {
    if (-not (Test-Path $pidFilePath)) {
        return $null
    }

    try {
        return Get-Content $pidFilePath -Raw | ConvertFrom-Json
    } catch {
        return $null
    }
}

function Get-TrackedProcess($session) {
    if ($null -eq $session -or -not $session.pid) {
        return $null
    }

    try {
        return Get-Process -Id ([int]$session.pid) -ErrorAction Stop
    } catch {
        return $null
    }
}

function Invoke-HealthProbe([string]$healthUrl) {
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        $response = Invoke-WebRequest -Uri $healthUrl -UseBasicParsing -TimeoutSec 5
        $stopwatch.Stop()
        return [pscustomobject]@{
            statusCode = [int]$response.StatusCode
            body = [string]$response.Content
            durationMs = $stopwatch.ElapsedMilliseconds
            ready = ($response.Content -match '"status"\s*:\s*"UP"')
        }
    } catch {
        $stopwatch.Stop()
        $statusCode = $null
        $body = $_.Exception.Message
        if ($_.Exception.Response -and $_.Exception.Response.StatusCode) {
            $statusCode = [int]$_.Exception.Response.StatusCode
        }

        return [pscustomobject]@{
            statusCode = $statusCode
            body = $body
            durationMs = $stopwatch.ElapsedMilliseconds
            ready = $false
        }
    }
}

function Get-LogExcerpt([string[]]$candidatePaths, [int]$tail = 40) {
    foreach ($candidate in $candidatePaths) {
        if (Test-Path $candidate) {
            return [pscustomobject]@{
                file = $candidate
                lines = @(Get-Content $candidate -Tail $tail)
            }
        }
    }

    return $null
}

$resolvedServiceDir = [System.IO.Path]::GetFullPath($ServiceDir)
if (-not (Test-Path $resolvedServiceDir)) {
    throw "ServiceDir not found: $resolvedServiceDir"
}

$targetDir = Get-AbsolutePath $resolvedServiceDir 'target'
if (-not (Test-Path $targetDir)) {
    New-Item -ItemType Directory -Path $targetDir | Out-Null
}

$pidFilePath = Get-AbsolutePath $resolvedServiceDir $PidFileName
$consoleLogPath = Get-AbsolutePath $resolvedServiceDir $ConsoleLog
$errorLogPath = Get-AbsolutePath $resolvedServiceDir $ErrorLog
$healthUrl = "http://localhost:$Port$HealthPath"

$trackedSession = Read-TrackedSession $pidFilePath
$trackedProcess = Get-TrackedProcess $trackedSession

switch ($Action) {
    'start' {
        if ($trackedProcess) {
            Write-Result ([pscustomobject]@{
                action = 'start'
                reused = $true
                pid = $trackedProcess.Id
                serviceDir = $resolvedServiceDir
                healthUrl = $healthUrl
                consoleLog = $consoleLogPath
                errorLog = $errorLogPath
            })
            break
        }

        $command = "$MavenWrapper quarkus:dev -Dquarkus.http.port=$Port $ExtraArgs"
        $process = Start-Process -FilePath 'cmd.exe' -ArgumentList "/c $command" -WorkingDirectory $resolvedServiceDir -RedirectStandardOutput $consoleLogPath -RedirectStandardError $errorLogPath -PassThru

        $session = [pscustomobject]@{
            pid = $process.Id
            serviceDir = $resolvedServiceDir
            port = $Port
            healthUrl = $healthUrl
            consoleLog = $consoleLogPath
            errorLog = $errorLogPath
            startedAt = (Get-Date).ToString('o')
        }

        $session | ConvertTo-Json -Depth 6 | Set-Content -Path $pidFilePath

        Write-Result ([pscustomobject]@{
            action = 'start'
            reused = $false
            pid = $process.Id
            serviceDir = $resolvedServiceDir
            healthUrl = $healthUrl
            consoleLog = $consoleLogPath
            errorLog = $errorLogPath
            pidFile = $pidFilePath
        })
    }

    'wait' {
        $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
        $lastProbe = $null

        while ((Get-Date) -lt $deadline) {
            $lastProbe = Invoke-HealthProbe $healthUrl
            if ($lastProbe.ready) {
                Write-Result ([pscustomobject]@{
                    action = 'wait'
                    ready = $true
                    serviceDir = $resolvedServiceDir
                    healthUrl = $healthUrl
                    probe = $lastProbe
                })
                exit 0
            }

            Start-Sleep -Milliseconds 1500
        }

        $excerpt = Get-LogExcerpt @(
            (Get-AbsolutePath $resolvedServiceDir 'target\quarkus.log'),
            $errorLogPath,
            $consoleLogPath
        )

        Write-Result ([pscustomobject]@{
            action = 'wait'
            ready = $false
            serviceDir = $resolvedServiceDir
            healthUrl = $healthUrl
            probe = $lastProbe
            logExcerpt = $excerpt
        })
        exit 2
    }

    'status' {
        $probe = Invoke-HealthProbe $healthUrl
        Write-Result ([pscustomobject]@{
            action = 'status'
            tracked = [bool]$trackedProcess
            pid = if ($trackedProcess) { $trackedProcess.Id } else { $null }
            serviceDir = $resolvedServiceDir
            healthUrl = $healthUrl
            probe = $probe
            pidFile = $pidFilePath
        })
    }

    'stop' {
        if (-not $trackedProcess) {
            if (Test-Path $pidFilePath) {
                Remove-Item $pidFilePath -Force
            }
            Write-Result ([pscustomobject]@{
                action = 'stop'
                stopped = $false
                reason = 'no-tracked-process'
                pidFile = $pidFilePath
            })
            break
        }

        Stop-Process -Id $trackedProcess.Id -Force
        if (Test-Path $pidFilePath) {
            Remove-Item $pidFilePath -Force
        }

        Write-Result ([pscustomobject]@{
            action = 'stop'
            stopped = $true
            pid = $trackedProcess.Id
            pidFile = $pidFilePath
        })
    }
}