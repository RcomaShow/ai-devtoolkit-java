param(
    [switch]$AuditOnly,
    [string]$Agent = "all"
)

$workspaceRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..\..\..')
$agentsDir = Join-Path $workspaceRoot '.github\agents'

$catalog = @(
    'team-lead',
    'developer',
    'bootstrap-workspace',
    'orchestrator',
    'agent-architect',
    'software-architect',
    'backend-engineer',
    'api-designer',
    'database-engineer',
    'tdd-validator',
    'test-coverage-engineer',
    'code-reviewer',
    'legacy-migration'
)

Write-Host "`n=== Agent Scaffolding Audit ===" -ForegroundColor Cyan
Write-Host "Agents dir: $agentsDir`n"

$targets = if ($Agent -eq 'all') { $catalog } else { @($Agent) }
$results = @()

foreach ($name in $targets) {
    $file = Join-Path $agentsDir "$name.agent.md"
    if (Test-Path $file) {
        $content = Get-Content $file -Raw
        $missing = @()
        foreach ($field in @('model:', 'effort:', 'agents:', 'description:')) {
            if ($content -notmatch $field) { $missing += $field }
        }
        if ($missing.Count -gt 0) {
            $results += [PSCustomObject]@{ Agent = $name; Status = 'INCOMPLETE'; Missing = ($missing -join ', ') }
        } else {
            $results += [PSCustomObject]@{ Agent = $name; Status = 'OK'; Missing = '' }
        }
    } else {
        $results += [PSCustomObject]@{ Agent = $name; Status = 'MISSING'; Missing = 'entire file' }
    }
}

$results | Format-Table -AutoSize

$missing = @($results | Where-Object { $_.Status -eq 'MISSING' })
$broken = @($results | Where-Object { $_.Status -eq 'INCOMPLETE' })

$publicAgents = @()
if (Test-Path $agentsDir) {
    $publicAgents = @(Get-ChildItem $agentsDir -Filter '*.agent.md' |
        Where-Object { Select-String -Path $_.FullName -Pattern '^user-invocable:\s*true$' -Quiet })
}

$expectedPublicAgents = @('developer.agent.md', 'team-lead.agent.md')
$actualPublicAgents = @($publicAgents | Select-Object -ExpandProperty Name | Sort-Object)
$surfaceDiff = Compare-Object -ReferenceObject $expectedPublicAgents -DifferenceObject $actualPublicAgents
$surfaceOk = ($actualPublicAgents.Count -eq $expectedPublicAgents.Count -and $surfaceDiff.Count -eq 0)
if ($surfaceOk) {
    Write-Host 'Public surface: team-lead + developer.' -ForegroundColor Green
} else {
    Write-Host 'Public surface issue: expected developer.agent.md and team-lead.agent.md to be public.' -ForegroundColor Yellow
    if ($publicAgents.Count -gt 0) {
        Write-Host ('  Public agents: ' + (($publicAgents | Select-Object -ExpandProperty Name) -join ', ')) -ForegroundColor Yellow
    }
}

if ($missing.Count -eq 0 -and $broken.Count -eq 0 -and $surfaceOk) {
    Write-Host 'All baseline agents present and complete.' -ForegroundColor Green
    exit 0
}

if ($AuditOnly) {
    Write-Host 'Audit-only mode: no files written.' -ForegroundColor Yellow
    exit ($missing.Count + $broken.Count + $(if ($surfaceOk) { 0 } else { 1 }))
}

Write-Host "`nMissing agents require scaffolding from toolkit templates." -ForegroundColor Yellow
Write-Host 'Incomplete agents: edit the file and add the missing frontmatter fields.' -ForegroundColor Yellow
Write-Host 'If the public surface is wrong, restore team-lead and developer as the only public agents.' -ForegroundColor Yellow

exit ($missing.Count + $broken.Count + $(if ($surfaceOk) { 0 } else { 1 }))