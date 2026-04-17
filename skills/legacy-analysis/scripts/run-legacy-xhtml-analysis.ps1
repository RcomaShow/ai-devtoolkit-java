param(
    [string]$Case,
    [string]$Title,
    [Parameter(Mandatory = $true)]
    [string]$Entrypoint,
    [Parameter(Mandatory = $true)]
    [string]$SourceRoot,
    [string]$RunId,
    [switch]$Force,
    [switch]$JsonOutput
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Resolve-NormalizedPath {
    param([string]$Value)

    return ([System.IO.Path]::GetFullPath($Value)).Replace('\', '/')
}

function Resolve-PythonCommand {
    $py = Get-Command py -ErrorAction SilentlyContinue
    if ($null -ne $py) {
        return @('py', '-3')
    }

    $python = Get-Command python -ErrorAction SilentlyContinue
    if ($null -ne $python) {
        return @('python')
    }

    throw 'Python launcher not found. Install Python or ensure `py` or `python` is on PATH.'
}

$workspaceRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..\..')).Path
$scaffoldScript = Join-Path $PSScriptRoot 'new-legacy-case.ps1'

$runIdValue = if ([string]::IsNullOrWhiteSpace($RunId)) { (Get-Date).ToString('yyyyMMdd-HHmmss') } else { $RunId }
$normalizedEntrypoint = Resolve-NormalizedPath $Entrypoint
$normalizedSourceRoot = Resolve-NormalizedPath $SourceRoot

$scaffoldArgs = @(
    '-NoProfile',
    '-NonInteractive',
    '-File', $scaffoldScript,
    '-Entrypoint', $normalizedEntrypoint,
    '-SourceRoot', $normalizedSourceRoot,
    '-RunId', $runIdValue,
    '-JsonOutput'
)

if (-not [string]::IsNullOrWhiteSpace($Case)) {
    $scaffoldArgs += @('-Case', $Case)
}
if (-not [string]::IsNullOrWhiteSpace($Title)) {
    $scaffoldArgs += @('-Title', $Title)
}
if ($Force.IsPresent) {
    $scaffoldArgs += '-Force'
}

$scaffoldResult = & powershell @scaffoldArgs | ConvertFrom-Json

$generatedRunRoot = $scaffoldResult.generatedRunRoot
$graphOutput = Join-Path $generatedRunRoot 'xhtml-db-graph.json'

$pythonCommand = Resolve-PythonCommand
$analyzeScript = Join-Path $workspaceRoot '.github\skills\java-flow-analysis\scripts\analyze-java.py'

$command = @($pythonCommand + @($analyzeScript, 'xhtml-db-graph', $normalizedSourceRoot, $normalizedEntrypoint))
$rawJson = & $command[0] $command[1..($command.Length - 1)]
$rawJson | Set-Content -Path $graphOutput -Encoding UTF8

$graph = Get-Content $graphOutput -Raw | ConvertFrom-Json
$runJsonPath = Join-Path $generatedRunRoot 'run.json'
$runJson = Get-Content $runJsonPath -Raw | ConvertFrom-Json
$runJson | Add-Member -NotePropertyName analysisArtifacts -NotePropertyValue ([pscustomobject]@{
    xhtmlDbGraph = 'xhtml-db-graph.json'
}) -Force
$runJson | Add-Member -NotePropertyName summary -NotePropertyValue ([pscustomobject]@{
    resolvedEntryBeanCount = $graph.summary.resolvedEntryBeanCount
    reachableClassCount = $graph.summary.reachableClassCount
    tableCount = $graph.summary.tableCount
    xhtmlFileCount = $graph.summary.xhtmlFileCount
}) -Force
$runJson | ConvertTo-Json -Depth 10 | Set-Content -Path $runJsonPath -Encoding UTF8

$caseJsonPath = Join-Path $scaffoldResult.caseRoot 'case.json'
$caseJson = Get-Content $caseJsonPath -Raw | ConvertFrom-Json
$caseJson.title = $scaffoldResult.title
$caseJson.updatedAt = (Get-Date).ToString('o')
$caseJson.sourceRoot = $normalizedSourceRoot
if ($null -ne $caseJson.entrypoint) {
    $caseJson.entrypoint.path = $normalizedEntrypoint
}
if ($null -ne $caseJson.artifacts) {
    $caseJson.artifacts.latestGeneratedRun = ('generated/' + $runIdValue)
}
$caseJson | ConvertTo-Json -Depth 10 | Set-Content -Path $caseJsonPath -Encoding UTF8

$result = [pscustomobject]@{
    caseId = $scaffoldResult.caseId
    title = $scaffoldResult.title
    caseRoot = $scaffoldResult.caseRoot
    generatedRunRoot = $generatedRunRoot
    graphOutput = $graphOutput
    summary = $runJson.summary
}

if ($JsonOutput) {
    $result | ConvertTo-Json -Depth 8
} else {
    $result
}