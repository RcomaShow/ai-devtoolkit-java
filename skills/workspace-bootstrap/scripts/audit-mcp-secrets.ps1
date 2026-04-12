param()

$workspaceRoot = Get-Location
$mcpFile = Join-Path $workspaceRoot '.vscode\mcp.json'

Write-Host "`n=== MCP Security Audit ===" -ForegroundColor Cyan
Write-Host "Workspace: $workspaceRoot`n"

if (-not (Test-Path $mcpFile)) {
    Write-Host ".vscode\mcp.json not found" -ForegroundColor Yellow
    exit 0
}

$json = Get-Content $mcpFile -Raw | ConvertFrom-Json
$issues = @()

function Test-SensitiveNode {
    param(
        [string]$Path,
        $Node
    )

    if ($null -eq $Node) { return }

    if ($Node -is [string]) {
        $sensitiveName = $Path -match '(?i)(token|password|secret|connection|user/pass|credential)'
        $isEnvReference = $Node -match '^\$\{env:[^}]+\}$'
        $looksEmbeddedCredential = $Node -match '(?i)(://[^\s]+:[^\s]+@|^[^\s/]+/[^\s@]+@|jdbc:)'
        if (($sensitiveName -or $looksEmbeddedCredential) -and -not $isEnvReference) {
            $script:issues += [PSCustomObject]@{ Path = $Path; Value = $Node }
        }
        return
    }

    if ($Node -is [System.Collections.IEnumerable] -and -not ($Node -is [string])) {
        $index = 0
        foreach ($item in $Node) {
            Test-SensitiveNode -Path "$Path[$index]" -Node $item
            $index += 1
        }
        return
    }

    foreach ($property in $Node.PSObject.Properties) {
        Test-SensitiveNode -Path "$Path.$($property.Name)" -Node $property.Value
    }
}

Test-SensitiveNode -Path '$' -Node $json

if ($issues.Count -eq 0) {
    Write-Host "No inline MCP secrets detected." -ForegroundColor Green
    exit 0
}

Write-Host "Inline or non-env MCP secrets detected:" -ForegroundColor Red
$issues | Format-Table -AutoSize
Write-Host "`nReplace sensitive values with `${env:...}` references." -ForegroundColor Yellow
exit $issues.Count