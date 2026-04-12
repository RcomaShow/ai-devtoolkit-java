param(
    [switch]$Full,
    [switch]$DriftOnly,
    [switch]$RefsOnly
)

$workspaceRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..\..\..')
$toolkitRoot = Join-Path $workspaceRoot '.ai-devtoolkit'
$runtimeRoot = Join-Path $workspaceRoot '.github'
$sourceAgentsDir = Join-Path $toolkitRoot 'agents'
$runtimeAgentsDir = Join-Path $runtimeRoot 'agents'
$sourceSkillsDir = Join-Path $toolkitRoot 'skills'
$runtimeSkillsDir = Join-Path $runtimeRoot 'skills'

$requiredAgentFields = @('description', 'tools', 'effort', 'argument-hint', 'agents', 'user-invocable')
$allowedModels = @('GPT-5 (copilot)', 'Claude Sonnet 4.5 (copilot)')
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

function Resolve-ToolkitReference {
    param(
        [string]$BaseDir,
        [string]$Reference
    )

    $normalized = $Reference.Trim().Trim('`')
    if ([string]::IsNullOrWhiteSpace($normalized)) {
        return $null
    }

    $normalized = $normalized -replace '/', '\\'
    if ($normalized -match '^(skills|workflows|agents|prompts|templates|mcp|adapters)\\') {
        return Join-Path $toolkitRoot $normalized
    }
    if ($normalized -match '^\.\\|^\.\.\\') {
        return Join-Path $BaseDir $normalized
    }

    return $null
}

function Get-RelativeReferences {
    param([string]$Content)

    $pattern = '`([^`]+?\.(?:md|ps1|mjs|json))`'
    return @([regex]::Matches($Content, $pattern) |
        ForEach-Object { $_.Groups[1].Value } |
        Select-Object -Unique)
}

Write-Host "`n=== Toolkit Health Audit ===" -ForegroundColor Cyan

$version = $null
$versionFile = Join-Path $toolkitRoot 'VERSION'
$changelogFile = Join-Path $toolkitRoot 'CHANGELOG.md'

Write-Host "`n--- Version Check ---" -ForegroundColor Yellow
if (Test-Path $versionFile) {
    $version = (Get-Content $versionFile -Raw).Trim()
    Write-Host "  Toolkit version: $version" -ForegroundColor Green
} else {
    Write-Host '  Missing VERSION file.' -ForegroundColor Red
}

if (Test-Path $changelogFile) {
    $latestVersionMatch = Select-String -Path $changelogFile -Pattern '^##\s+([0-9]+\.[0-9]+\.[0-9]+)' | Select-Object -First 1
    if ($latestVersionMatch) {
        $latestChangelogVersion = $latestVersionMatch.Matches[0].Groups[1].Value
        if ($version -and $version -eq $latestChangelogVersion) {
            Write-Host "  CHANGELOG latest entry matches VERSION ($latestChangelogVersion)." -ForegroundColor Green
        } else {
            Write-Host "  VERSION/CHANGELOG mismatch: VERSION=$version CHANGELOG=$latestChangelogVersion" -ForegroundColor Red
        }
    }
}

Write-Host "`n--- Agent Drift ---" -ForegroundColor Yellow
$sourceAgents = @()
$runtimeAgents = @()

if (Test-Path $sourceAgentsDir) {
    $sourceAgents = @(Get-ChildItem $sourceAgentsDir -Filter '*.agent.md' | Select-Object -ExpandProperty Name | Sort-Object)
}
if (Test-Path $runtimeAgentsDir) {
    $runtimeAgents = @(Get-ChildItem $runtimeAgentsDir -Filter '*.agent.md' | Select-Object -ExpandProperty Name | Sort-Object)
}

$missingFromRuntime = @($sourceAgents | Where-Object { $_ -notin $runtimeAgents })
$extraInRuntime = @($runtimeAgents | Where-Object { $_ -notin $sourceAgents })

if ($missingFromRuntime.Count -eq 0 -and $extraInRuntime.Count -eq 0) {
    Write-Host '  Agents: in sync.' -ForegroundColor Green
} else {
    if ($missingFromRuntime.Count -gt 0) {
        Write-Host "  Missing from runtime: $($missingFromRuntime -join ', ')" -ForegroundColor Red
    }
    if ($extraInRuntime.Count -gt 0) {
        Write-Host "  Extra in runtime (workspace custom): $($extraInRuntime -join ', ')" -ForegroundColor Cyan
    }
}

Write-Host "`n--- Skill Drift ---" -ForegroundColor Yellow
$sourceSkills = @()
$runtimeSkills = @()

if (Test-Path $sourceSkillsDir) {
    $sourceSkills = @(Get-ChildItem $sourceSkillsDir -Directory |
        Where-Object { Test-Path (Join-Path $_.FullName 'SKILL.md') } |
        Select-Object -ExpandProperty Name | Sort-Object)
}
if (Test-Path $runtimeSkillsDir) {
    $runtimeSkills = @(Get-ChildItem $runtimeSkillsDir -Directory |
        Where-Object { Test-Path (Join-Path $_.FullName 'SKILL.md') } |
        Select-Object -ExpandProperty Name | Sort-Object)
}

$missingSkills = @($sourceSkills | Where-Object { $_ -notin $runtimeSkills })
$extraSkills = @($runtimeSkills | Where-Object { $_ -notin $sourceSkills })

if ($missingSkills.Count -eq 0) {
    Write-Host "  Skills: $($sourceSkills.Count) source, $($runtimeSkills.Count) runtime. Core skills in sync." -ForegroundColor Green
} else {
    Write-Host "  Missing from runtime: $($missingSkills -join ', ')" -ForegroundColor Red
}
if ($extraSkills.Count -gt 0) {
    Write-Host "  Extra in runtime (repo-context or workspace custom): $($extraSkills.Count)" -ForegroundColor Cyan
}

if ($DriftOnly) {
    Write-Host "`n=== Audit Complete ===" -ForegroundColor Cyan
    exit 0
}

if ($Full -or $RefsOnly -or (-not $DriftOnly)) {
    Write-Host "`n--- Broken References ---" -ForegroundColor Yellow
    $referenceIssues = 0
    $filesToScan = @()

    if (Test-Path $toolkitRoot) {
        $filesToScan = @(Get-ChildItem $toolkitRoot -Recurse -File -Include '*.agent.md', 'SKILL.md', '*.workflow.md', '*.prompt.md', 'copilot-instructions.md')
    }

    foreach ($file in $filesToScan) {
        $content = Get-Content $file.FullName -Raw
        foreach ($reference in (Get-RelativeReferences -Content $content)) {
            $resolvedPath = Resolve-ToolkitReference -BaseDir $file.Directory.FullName -Reference $reference
            if ($resolvedPath -and -not (Test-Path $resolvedPath)) {
                Write-Host "  BROKEN: $($file.Name) -> $reference" -ForegroundColor Red
                $referenceIssues++
            }
        }
    }

    if ($referenceIssues -eq 0) {
        Write-Host '  No broken file references detected in toolkit docs and manifests.' -ForegroundColor Green
    }
}

if ($RefsOnly) {
    Write-Host "`n=== Audit Complete ===" -ForegroundColor Cyan
    exit 0
}

Write-Host "`n--- Orphaned Toolkit Assets ---" -ForegroundColor Yellow
$orphanCount = 0

if (Test-Path $sourceSkillsDir) {
    foreach ($skill in (Get-ChildItem $sourceSkillsDir -Directory)) {
        foreach ($sub in (Get-ChildItem $skill.FullName -Directory -ErrorAction SilentlyContinue)) {
            $nestedSkill = Join-Path $sub.FullName 'SKILL.md'
            if (Test-Path $nestedSkill) {
                $referenceFile = Join-Path $skill.FullName (Join-Path 'references' ($sub.Name + '.md'))
                if (Test-Path $referenceFile) {
                    Write-Host "  ORPHAN: $($skill.Name)/$($sub.Name)/SKILL.md duplicates references/$($sub.Name).md" -ForegroundColor Yellow
                    $orphanCount++
                } else {
                    Write-Host "  WARN: $($skill.Name)/$($sub.Name)/SKILL.md has no matching reference file" -ForegroundColor Yellow
                }
            }
        }
    }
}

if ($orphanCount -eq 0) {
    Write-Host '  No orphaned nested sub-skills detected.' -ForegroundColor Green
}

Write-Host "`n--- Catalog Consistency ---" -ForegroundColor Yellow
$catalogIssues = 0

if (Test-Path $sourceAgentsDir) {
    foreach ($agentFile in (Get-ChildItem $sourceAgentsDir -Filter '*.agent.md')) {
        $content = Get-Content $agentFile.FullName -Raw
        $frontmatter = Get-FrontmatterBlock -Content $content
        $agentName = [System.IO.Path]::GetFileNameWithoutExtension([System.IO.Path]::GetFileNameWithoutExtension($agentFile.Name))

        if (-not $frontmatter) {
            Write-Host "  $($agentFile.Name): missing frontmatter block" -ForegroundColor Red
            $catalogIssues++
            continue
        }

        foreach ($field in $requiredAgentFields) {
            if (-not (Get-FrontmatterValue -Frontmatter $frontmatter -Field $field)) {
                Write-Host "  $($agentFile.Name): missing $field" -ForegroundColor Red
                $catalogIssues++
            }
        }

        $nameValue = Get-FrontmatterValue -Frontmatter $frontmatter -Field 'name'
        if ($nameValue -and $nameValue -ne $agentName) {
            Write-Host "  $($agentFile.Name): name '$nameValue' does not match filename '$agentName'" -ForegroundColor Red
            $catalogIssues++
        }

        $modelValue = Get-FrontmatterValue -Frontmatter $frontmatter -Field 'model'
        if ($modelValue) {
            $invalidModels = @(Parse-FrontmatterList -Raw $modelValue | Where-Object { $allowedModels -notcontains $_ })
            if ($invalidModels.Count -gt 0) {
                Write-Host "  $($agentFile.Name): invalid model aliases: $($invalidModels -join ', ')" -ForegroundColor Red
                $catalogIssues++
            }
        }

        if ($agentName -eq 'team-lead' -and -not $modelValue) {
            Write-Host "  $($agentFile.Name): team-lead should pin documented Copilot model aliases" -ForegroundColor Red
            $catalogIssues++
        }

        $toolsValue = Get-FrontmatterValue -Frontmatter $frontmatter -Field 'tools'
        if ($toolsValue) {
            $invalidTools = @(Parse-FrontmatterList -Raw $toolsValue | Where-Object { -not (Test-AllowedTool -Tool $_) })
            if ($invalidTools.Count -gt 0) {
                Write-Host "  $($agentFile.Name): invalid tool aliases: $($invalidTools -join ', ')" -ForegroundColor Red
                $catalogIssues++
            }
        }
    }
}

if ($catalogIssues -eq 0) {
    Write-Host '  Agent frontmatter is consistent with the toolkit rules.' -ForegroundColor Green
}

Write-Host "`n=== Audit Complete ===" -ForegroundColor Cyan
