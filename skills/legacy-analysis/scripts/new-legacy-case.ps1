param(
    [string]$Case,
    [string]$Title,
    [string]$Entrypoint,
    [string]$EntrypointType = 'xhtml',
    [string]$SourceRoot,
    [string]$RunId,
    [switch]$Force,
    [switch]$JsonOutput
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Convert-ToCaseId {
    param([string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return ''
    }

    $normalized = $Value.ToLowerInvariant()
    $normalized = [regex]::Replace($normalized, '[^a-z0-9]+', '-')
    $normalized = $normalized.Trim('-')
    return $normalized
}

function Resolve-OptionalPath {
    param([string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return ''
    }

    return ([System.IO.Path]::GetFullPath($Value)).Replace('\', '/')
}

function Ensure-Directory {
    param([string]$Path)

    if (-not (Test-Path $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function Render-Template {
    param(
        [string]$TemplatePath,
        [hashtable]$Tokens
    )

    $content = Get-Content $TemplatePath -Raw
    foreach ($key in $Tokens.Keys) {
        $content = $content.Replace($key, [string]$Tokens[$key])
    }
    return $content
}

function Write-RenderedTemplate {
    param(
        [string]$TemplatePath,
        [string]$TargetPath,
        [hashtable]$Tokens,
        [bool]$Overwrite
    )

    if ((Test-Path $TargetPath) -and -not $Overwrite) {
        return $false
    }

    $rendered = Render-Template -TemplatePath $TemplatePath -Tokens $Tokens
    Set-Content -Path $TargetPath -Value $rendered -Encoding UTF8
    return $true
}

$workspaceRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..\..')).Path
$legacyRoot = Join-Path $workspaceRoot '.github\legacy'
$templatesRoot = Join-Path $legacyRoot 'templates'

if (-not (Test-Path $templatesRoot)) {
    throw "Legacy templates not found at $templatesRoot. Initialize the workspace legacy surface first."
}

$caseId = Convert-ToCaseId $Case
if ([string]::IsNullOrWhiteSpace($caseId)) {
    if (-not [string]::IsNullOrWhiteSpace($Title)) {
        $caseId = Convert-ToCaseId $Title
    } elseif (-not [string]::IsNullOrWhiteSpace($Entrypoint)) {
        $caseId = Convert-ToCaseId ([System.IO.Path]::GetFileNameWithoutExtension($Entrypoint))
    }
}

if ([string]::IsNullOrWhiteSpace($caseId)) {
    throw 'Provide -Case, -Title, or -Entrypoint so a case id can be derived.'
}

$resolvedEntrypoint = Resolve-OptionalPath $Entrypoint
$resolvedSourceRoot = Resolve-OptionalPath $SourceRoot
$runIdValue = if ([string]::IsNullOrWhiteSpace($RunId)) { (Get-Date).ToString('yyyyMMdd-HHmmss') } else { $RunId }
$titleValue = if ([string]::IsNullOrWhiteSpace($Title)) {
    (($caseId -split '-') | ForEach-Object {
        if ([string]::IsNullOrWhiteSpace($_)) { return '' }
        return $_.Substring(0, 1).ToUpperInvariant() + $_.Substring(1)
    }) -join ' '
} else {
    $Title
}

$caseRoot = Join-Path $legacyRoot (Join-Path 'cases' $caseId)
$generatedRunRoot = Join-Path $caseRoot (Join-Path 'generated' $runIdValue)

Ensure-Directory $caseRoot
Ensure-Directory $generatedRunRoot

$timestamp = (Get-Date).ToString('o')
$tokens = @{
    '{case-id}' = $caseId
    '{title}' = $titleValue
    '{entrypoint}' = if ($resolvedEntrypoint) { $resolvedEntrypoint } else { '{entrypoint}' }
    '{entrypoint-type}' = $EntrypointType
    '{source-root}' = if ($resolvedSourceRoot) { $resolvedSourceRoot } else { '{source-root}' }
    '{run-id}' = $runIdValue
    '{created-at}' = $timestamp
    '{updated-at}' = $timestamp
}

$written = @()

$caseJson = Join-Path $caseRoot 'case.json'
if (Write-RenderedTemplate -TemplatePath (Join-Path $templatesRoot 'legacy-case.template.json') -TargetPath $caseJson -Tokens $tokens -Overwrite $Force.IsPresent) {
    $written += $caseJson
}

foreach ($fileName in @('legacy-analysis.template.md', 'java-class-logic.template.md', 'oracle-sql-inventory.template.md')) {
    $targetName = switch ($fileName) {
        'legacy-analysis.template.md' { 'analysis.md' }
        'java-class-logic.template.md' { 'java-class-logic.md' }
        'oracle-sql-inventory.template.md' { 'oracle-sql-inventory.md' }
        default { throw "Unhandled template: $fileName" }
    }

    $targetPath = Join-Path $caseRoot $targetName
    if (Write-RenderedTemplate -TemplatePath (Join-Path $templatesRoot $fileName) -TargetPath $targetPath -Tokens $tokens -Overwrite $Force.IsPresent) {
        $written += $targetPath
    }
}

$runJson = Join-Path $generatedRunRoot 'run.json'
if (Write-RenderedTemplate -TemplatePath (Join-Path $templatesRoot 'generated-run.template.json') -TargetPath $runJson -Tokens $tokens -Overwrite $true) {
    $written += $runJson
}

$result = [pscustomobject]@{
    caseId = $caseId
    title = $titleValue
    caseRoot = $caseRoot
    generatedRunRoot = $generatedRunRoot
    written = $written
}

if ($JsonOutput) {
    $result | ConvertTo-Json -Depth 6
} else {
    $result
}