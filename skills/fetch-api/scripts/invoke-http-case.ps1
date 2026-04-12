param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('GET', 'POST', 'PUT', 'PATCH', 'DELETE')]
    [string]$Method,

    [Parameter(Mandatory = $true)]
    [string]$Uri,

    [string]$CompareUri,
    [string]$HeadersJson,
    [string]$BodyFile,
    [string]$BodyJson,
    [int]$ExpectedStatus = 0,
    [int]$TimeoutSeconds = 30,
    [string]$LogFile = 'target\quarkus.log',
    [int]$LogTail = 40,
    [switch]$JsonOutput
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function To-Hashtable($jsonText) {
    if ([string]::IsNullOrWhiteSpace($jsonText)) {
        return @{}
    }

    $raw = $jsonText | ConvertFrom-Json -Depth 20
    $table = @{}
    $raw.PSObject.Properties | ForEach-Object {
        $table[$_.Name] = [string]$_.Value
    }
    return $table
}

function Convert-Body([string]$bodyPath, [string]$inlineBody) {
    if (-not [string]::IsNullOrWhiteSpace($inlineBody)) {
        return $inlineBody
    }

    if (-not [string]::IsNullOrWhiteSpace($bodyPath)) {
        return Get-Content $bodyPath -Raw
    }

    return $null
}

function Try-ParseJson([string]$text) {
    if ([string]::IsNullOrWhiteSpace($text)) {
        return $null
    }

    try {
        return $text | ConvertFrom-Json -Depth 30
    } catch {
        return $null
    }
}

function Get-LogExcerpt([string]$path, [int]$tail) {
    if (-not (Test-Path $path)) {
        return $null
    }

    return [pscustomobject]@{
        file = [System.IO.Path]::GetFullPath($path)
        lines = @(Get-Content $path -Tail $tail)
    }
}

function Invoke-RecordedRequest(
    [string]$requestMethod,
    [string]$requestUri,
    [hashtable]$headers,
    [string]$body,
    [int]$timeoutSeconds,
    [int]$expectedStatus,
    [string]$logFile,
    [int]$logTail
) {
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $responseText = $null
    $responseHeaders = @{}
    $statusCode = $null
    $errorText = $null

    $params = @{
        Uri = $requestUri
        Method = $requestMethod
        TimeoutSec = $timeoutSeconds
        UseBasicParsing = $true
        Headers = $headers
    }

    if ($null -ne $body -and $requestMethod -in @('POST', 'PUT', 'PATCH')) {
        $params['Body'] = $body
    }

    try {
        $response = Invoke-WebRequest @params
        $statusCode = [int]$response.StatusCode
        $responseText = [string]$response.Content
        foreach ($headerKey in $response.Headers.Keys) {
            $responseHeaders[$headerKey] = [string]$response.Headers[$headerKey]
        }
    } catch {
        $errorText = $_.Exception.Message
        if ($_.Exception.Response) {
            $statusCode = [int]$_.Exception.Response.StatusCode
            try {
                $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
                $responseText = $reader.ReadToEnd()
                $reader.Close()
            } catch {
                $responseText = $errorText
            }
        } else {
            $responseText = $errorText
        }
    } finally {
        $stopwatch.Stop()
    }

    $parsedJson = Try-ParseJson $responseText
    $ok = if ($expectedStatus -gt 0) { $statusCode -eq $expectedStatus } else { $statusCode -ge 200 -and $statusCode -lt 300 }
    $logExcerpt = $null
    if ($statusCode -ge 500) {
        $logExcerpt = Get-LogExcerpt $logFile $logTail
    }

    return [pscustomobject]@{
        method = $requestMethod
        uri = $requestUri
        statusCode = $statusCode
        expectedStatus = if ($expectedStatus -gt 0) { $expectedStatus } else { $null }
        ok = $ok
        durationMs = $stopwatch.ElapsedMilliseconds
        headers = $responseHeaders
        body = if ($parsedJson) { $parsedJson } else { $responseText }
        error = $errorText
        logExcerpt = $logExcerpt
    }
}

$headers = To-Hashtable $HeadersJson
$body = Convert-Body $BodyFile $BodyJson
$primary = Invoke-RecordedRequest $Method $Uri $headers $body $TimeoutSeconds $ExpectedStatus $LogFile $LogTail
$comparison = $null

if (-not [string]::IsNullOrWhiteSpace($CompareUri)) {
    $comparison = Invoke-RecordedRequest $Method $CompareUri $headers $body $TimeoutSeconds $ExpectedStatus $LogFile $LogTail
}

$result = [pscustomobject]@{
    primary = $primary
    comparison = $comparison
    drift = if ($comparison) {
        [pscustomobject]@{
            statusCodeDiffers = ($primary.statusCode -ne $comparison.statusCode)
            bodyDiffers = ((ConvertTo-Json $primary.body -Depth 20) -ne (ConvertTo-Json $comparison.body -Depth 20))
        }
    } else {
        $null
    }
}

if ($JsonOutput) {
    $result | ConvertTo-Json -Depth 20
} else {
    $result
}