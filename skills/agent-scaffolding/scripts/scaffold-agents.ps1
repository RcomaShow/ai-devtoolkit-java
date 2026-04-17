param(
    [switch]$AuditOnly,
    [string]$Agent = "all"
)

$workspaceRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..\..\..')
$agentsDir = Join-Path $workspaceRoot '.github\agents'

$catalog = @(
    'team-lead',
    'developer',
    'memory-manager',
    'context-optimizer',
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
    'legacy-migration',
    'xhtml-db-tracer'
)

$requiredFields = @('description', 'tools', 'effort', 'argument-hint', 'agents', 'user-invocable')
$allowedModels = @('GPT-5.4', 'GPT-5.3 Codex', 'Claude Sonnet 4.6', 'Claude Opus 4.6')
$allowedToolAliases = @('read', 'search', 'edit', 'execute', 'todo', 'agent', 'web')

function Get-FrontmatterBlock {
    param([string]$Content)

    $match = [regex]::Match($Content, '(?ms)^---\s*\r?\n(.*?)\r?\n---')
    if ($match.Success) {
        return $match.Groups[1].Value
    }

    return $null
}

function Get-FrontmatterValue {
    param(
        [string]$Frontmatter,
        [string]$Field
    )

    if ([string]::IsNullOrWhiteSpace($Frontmatter)) {
        return $null
    }

    $pattern = '(?m)^' + [regex]::Escape($Field) + ':\s*(.+)$'
    $match = [regex]::Match($Frontmatter, $pattern)
    if ($match.Success) {
        return $match.Groups[1].Value.Trim()
    }

    return $null
}

function Parse-FrontmatterList {
    param([string]$Raw)

    if ([string]::IsNullOrWhiteSpace($Raw)) {
        return @()
    }

    $trimmed = $Raw.Trim()
    if ($trimmed.StartsWith('[') -and $trimmed.EndsWith(']')) {
        $trimmed = $trimmed.Substring(1, $trimmed.Length - 2)
    }

    if ([string]::IsNullOrWhiteSpace($trimmed)) {
        return @()
    }

    return @($trimmed.Split(',') |
        ForEach-Object { $_.Trim().Trim('"').Trim("'") } |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
}

function Test-AllowedTool {
    param([string]$Tool)

    return ($allowedToolAliases -contains $Tool) -or ($Tool -match '^[A-Za-z0-9._-]+/\*$')
}

Write-Host "`n=== Agent Scaffolding Audit ===" -ForegroundColor Cyan
Write-Host "Agents dir: $agentsDir`n"

$targets = if ($Agent -eq 'all') { $catalog } else { @($Agent) }
$results = @()

foreach ($name in $targets) {
    $file = Join-Path $agentsDir "$name.agent.md"
    if (-not (Test-Path $file)) {
        $results += [PSCustomObject]@{ Agent = $name; Status = 'MISSING'; Issues = 'entire file' }
        continue
    }

    $content = Get-Content $file -Raw
    $frontmatter = Get-FrontmatterBlock $content
    $issues = @()

    if (-not $frontmatter) {
        $issues += 'missing frontmatter block'
    } else {
        foreach ($field in $requiredFields) {
            if (-not (Get-FrontmatterValue -Frontmatter $frontmatter -Field $field)) {
                $issues += "missing $field"
            }
        }

        $nameValue = Get-FrontmatterValue -Frontmatter $frontmatter -Field 'name'
        if ($nameValue -and $nameValue -ne $name) {
            $issues += "name '$nameValue' does not match filename '$name'"
        }

        $modelValue = Get-FrontmatterValue -Frontmatter $frontmatter -Field 'model'
        if ($modelValue) {
            $invalidModels = @(Parse-FrontmatterList -Raw $modelValue | Where-Object { $allowedModels -notcontains $_ })
            if ($invalidModels.Count -gt 0) {
                $issues += ('invalid model alias: ' + ($invalidModels -join ', '))
            }
        }

        if ($name -eq 'team-lead' -and -not $modelValue) {
            $issues += 'team-lead should pin documented Copilot model aliases'
        }

        $toolsValue = Get-FrontmatterValue -Frontmatter $frontmatter -Field 'tools'
        if ($toolsValue) {
            $invalidTools = @(Parse-FrontmatterList -Raw $toolsValue | Where-Object { -not (Test-AllowedTool -Tool $_) })
            if ($invalidTools.Count -gt 0) {
                $issues += ('invalid tool alias: ' + ($invalidTools -join ', '))
            }
        }
    }

    if ($issues.Count -gt 0) {
        $results += [PSCustomObject]@{ Agent = $name; Status = 'INCOMPLETE'; Issues = ($issues -join '; ') }
    } else {
        $results += [PSCustomObject]@{ Agent = $name; Status = 'OK'; Issues = '' }
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

$plannerChainOk = $true
$teamLeadFile = Join-Path $agentsDir 'team-lead.agent.md'
if (Test-Path $teamLeadFile) {
    $teamLeadContent = Get-Content $teamLeadFile -Raw
    $teamLeadFrontmatter = Get-FrontmatterBlock -Content $teamLeadContent
    $teamLeadDelegates = Parse-FrontmatterList -Raw (Get-FrontmatterValue -Frontmatter $teamLeadFrontmatter -Field 'agents')
    if ($teamLeadDelegates -notcontains 'orchestrator') {
        Write-Host 'Planner chain issue: team-lead should delegate to orchestrator as the hidden planning stage.' -ForegroundColor Yellow
        $plannerChainOk = $false
    }
}

if ($missing.Count -eq 0 -and $broken.Count -eq 0 -and $surfaceOk -and $plannerChainOk) {
    Write-Host 'All baseline agents present and complete.' -ForegroundColor Green
    exit 0
}

if ($AuditOnly) {
    Write-Host 'Audit-only mode: no files written.' -ForegroundColor Yellow
    exit ($missing.Count + $broken.Count + $(if ($surfaceOk) { 0 } else { 1 }))
}

Write-Host "`nMissing agents require scaffolding from toolkit templates." -ForegroundColor Yellow
Write-Host 'Incomplete agents: fix frontmatter, model aliases, and tool aliases before relying on discovery.' -ForegroundColor Yellow
Write-Host 'If the public surface is wrong, restore team-lead and developer as the only public agents.' -ForegroundColor Yellow

if (-not $plannerChainOk) {
    Write-Host 'Restore the hidden planner chain by delegating from team-lead to orchestrator.' -ForegroundColor Yellow
}

exit ($missing.Count + $broken.Count + $(if ($surfaceOk) { 0 } else { 1 }) + $(if ($plannerChainOk) { 0 } else { 1 }))