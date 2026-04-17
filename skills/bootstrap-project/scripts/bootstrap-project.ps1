param(
    [string]$Repo = "all"
)

$workspaceRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..\..\..')
$agentsDir = Join-Path $workspaceRoot '.github\agents'
$skillsDir = Join-Path $workspaceRoot '.github\skills'
$inventoryFile = Join-Path $workspaceRoot '.ai\memory\workspace-map.json'
$controlPlaneFile = Join-Path $workspaceRoot '.github\bootstrap\control-plane.json'
$mcpFile = Join-Path $workspaceRoot '.vscode\mcp.json'
$mcpRegistryFile = Join-Path $workspaceRoot '.ai\memory\mcp-registry.json'

function Get-WorkspaceMap {
    param(
        [string]$InventoryPath
    )

    if (Test-Path $InventoryPath) {
        return Get-Content $InventoryPath -Raw | ConvertFrom-Json
    }

    return $null
}

function Get-ControlPlane {
    param(
        [string]$ControlPlanePath
    )

    $defaultControlPlane = [PSCustomObject]@{
        shellMemory = [PSCustomObject]@{
            path = '.github/memory/workspace-shell.md'
            owner = 'developer'
            managedByBootstrap = $false
        }
        managedTargets = @()
        mcpPolicy = [PSCustomObject]@{
            source = '.vscode/mcp.json'
            baselineRequired = @('oracle-official', 'bitbucket-corporate')
            optional = @()
        }
    }

    if (-not (Test-Path $ControlPlanePath)) {
        return $defaultControlPlane
    }

    try {
        $parsed = Get-Content $ControlPlanePath -Raw | ConvertFrom-Json
        return [PSCustomObject]@{
            shellMemory = [PSCustomObject]@{
                path = if ($null -ne $parsed.shellMemory -and $parsed.shellMemory.path) { $parsed.shellMemory.path } else { $defaultControlPlane.shellMemory.path }
                owner = if ($null -ne $parsed.shellMemory -and $parsed.shellMemory.owner) { $parsed.shellMemory.owner } else { $defaultControlPlane.shellMemory.owner }
                managedByBootstrap = if ($null -ne $parsed.shellMemory -and $null -ne $parsed.shellMemory.managedByBootstrap) { [bool]$parsed.shellMemory.managedByBootstrap } else { $defaultControlPlane.shellMemory.managedByBootstrap }
            }
            managedTargets = if ($null -ne $parsed.managedTargets) { @($parsed.managedTargets) } else { @() }
            mcpPolicy = [PSCustomObject]@{
                source = if ($null -ne $parsed.mcpPolicy -and $parsed.mcpPolicy.source) { $parsed.mcpPolicy.source } else { $defaultControlPlane.mcpPolicy.source }
                baselineRequired = if ($null -ne $parsed.mcpPolicy -and $null -ne $parsed.mcpPolicy.baselineRequired -and @($parsed.mcpPolicy.baselineRequired).Count -gt 0) { @($parsed.mcpPolicy.baselineRequired) } else { $defaultControlPlane.mcpPolicy.baselineRequired }
                optional = if ($null -ne $parsed.mcpPolicy -and $null -ne $parsed.mcpPolicy.optional) { @($parsed.mcpPolicy.optional) } else { $defaultControlPlane.mcpPolicy.optional }
            }
        }
    }
    catch {
        return $defaultControlPlane
    }
}

function Get-RepositoryNames {
    param(
        [string]$TargetRepo,
        [object]$WorkspaceMap,
        [string]$RootPath
    )

    if ($TargetRepo -ne 'all') {
        return @($TargetRepo)
    }

    if ($null -ne $WorkspaceMap -and $null -ne $WorkspaceMap.repositories) {
        return @($WorkspaceMap.repositories | ForEach-Object { $_.path })
    }

    return @(Get-ChildItem $RootPath -Directory |
        Where-Object { Test-Path (Join-Path $_.FullName '.git') } |
        Select-Object -ExpandProperty Name)
}

function Get-ManagedTargets {
    param(
        [object]$WorkspaceMap,
        [object]$ControlPlane
    )

    $targets = New-Object System.Collections.Generic.List[object]
    $seen = @{}

    if ($null -ne $WorkspaceMap -and $null -ne $WorkspaceMap.managedTargets) {
        foreach ($target in @($WorkspaceMap.managedTargets)) {
            if ($null -eq $target -or [string]::IsNullOrWhiteSpace([string]$target.path)) {
                continue
            }

            if ($seen.ContainsKey([string]$target.path)) {
                continue
            }

            $seen[[string]$target.path] = $true
            $targets.Add([PSCustomObject]@{
                Name = if ($target.name) { [string]$target.name } else { [string]$target.path }
                Path = [string]$target.path
                Kind = if ($target.kind) { [string]$target.kind } else { 'workspace-service' }
                ContextSurface = if ($target.contextSurface) { [string]$target.contextSurface } else { 'workspace-shell' }
                Detection = if ($target.detection) { [string]$target.detection } else { 'declared' }
            })
        }

        return @($targets | Sort-Object Path)
    }

    if ($null -ne $WorkspaceMap -and $null -ne $WorkspaceMap.repositories) {
        foreach ($repo in @($WorkspaceMap.repositories)) {
            if ($seen.ContainsKey([string]$repo.path)) {
                continue
            }

            $seen[[string]$repo.path] = $true
            $targets.Add([PSCustomObject]@{
                Name = [string]$repo.name
                Path = [string]$repo.path
                Kind = 'repository'
                ContextSurface = 'repo-local'
                Detection = 'git'
            })
        }
    }

    if ($null -ne $ControlPlane -and $null -ne $ControlPlane.managedTargets) {
        foreach ($target in @($ControlPlane.managedTargets)) {
            if ($null -eq $target -or [string]::IsNullOrWhiteSpace([string]$target.path)) {
                continue
            }

            if ($seen.ContainsKey([string]$target.path)) {
                continue
            }

            $seen[[string]$target.path] = $true
            $targets.Add([PSCustomObject]@{
                Name = if ($target.name) { [string]$target.name } else { [string]$target.path }
                Path = [string]$target.path
                Kind = if ($target.kind) { [string]$target.kind } else { 'workspace-service' }
                ContextSurface = if ($target.contextSurface) { [string]$target.contextSurface } else { 'workspace-shell' }
                Detection = 'declared'
            })
        }
    }

    return @($targets | Sort-Object Path)
}

Write-Host "`n=== Project Bootstrap -- Phase 2 ===" -ForegroundColor Cyan
Write-Host "Workspace: $workspaceRoot`n"

$workspaceMap = Get-WorkspaceMap -InventoryPath $inventoryFile
$controlPlane = Get-ControlPlane -ControlPlanePath $controlPlaneFile
$workspaceShellFile = Join-Path $workspaceRoot (($controlPlane.shellMemory.path -replace '/', '\'))

Write-Host "--- Step 1: Agent Catalog ---" -ForegroundColor Yellow
$auditScript = Join-Path $workspaceRoot '.github\skills\agent-scaffolding\scripts\scaffold-agents.ps1'
& powershell -NoProfile -NonInteractive -File $auditScript -AuditOnly
$catalogOk = ($LASTEXITCODE -eq 0)

Write-Host "`n--- Step 2: Public Agent Surface ---" -ForegroundColor Yellow
$publicAgents = @()
if (Test-Path $agentsDir) {
    $publicAgents = @(Get-ChildItem $agentsDir -Filter '*.agent.md' |
        Where-Object { Select-String -Path $_.FullName -Pattern '^user-invocable:\s*true$' -Quiet })
}

$expectedPublicAgents = @('developer.agent.md', 'team-lead.agent.md')
$actualPublicAgents = @($publicAgents | Select-Object -ExpandProperty Name | Sort-Object)
$surfaceDiff = Compare-Object -ReferenceObject $expectedPublicAgents -DifferenceObject $actualPublicAgents
$surfaceOk = ($actualPublicAgents.Count -eq $expectedPublicAgents.Count -and $surfaceDiff.Count -eq 0)
$surfaceColor = if ($surfaceOk) { 'Green' } else { 'Yellow' }
$surfaceLabel = if ($surfaceOk) { 'OK' } else { 'REVIEW NEEDED' }
Write-Host "Public surface: $surfaceLabel" -ForegroundColor $surfaceColor
if ($publicAgents.Count -eq 0) {
    Write-Host '  No public agents found.' -ForegroundColor Yellow
} else {
    Write-Host ('  Public agents: ' + (($publicAgents | Select-Object -ExpandProperty Name) -join ', '))
}

Write-Host "`n--- Step 3: Repo Context Coverage ---" -ForegroundColor Yellow
$targets = Get-RepositoryNames -TargetRepo $Repo -WorkspaceMap $workspaceMap -RootPath $workspaceRoot
$repoResults = @()

foreach ($repoName in $targets) {
    $repoExists = Test-Path (Join-Path $workspaceRoot $repoName)
    $normalizedRepo = $repoName -replace '[-_]', '-'
    $matchingSkills = @()
    $memoryRoot = Join-Path $workspaceRoot "$repoName\.github\memory"
    $memoryFiles = @('context.md', 'dependencies.md', 'recent-changes.md') | Where-Object {
        Test-Path (Join-Path $memoryRoot $_)
    }
    $memoryOk = ($memoryFiles.Count -eq 3)

    if (Test-Path $skillsDir) {
        $matchingSkills = @(Get-ChildItem $skillsDir -Directory |
            Where-Object { $_.Name -like "*-$normalizedRepo" })
    }

    $status = if (-not $repoExists) {
        'REPO_MISSING'
    } elseif ($matchingSkills.Count -gt 0 -and $memoryOk) {
        'OK'
    } elseif ($matchingSkills.Count -gt 0) {
        'MEMORY_MISSING'
    } elseif ($memoryOk) {
        'CONTEXT_MISSING'
    } else {
        'CONTEXT_AND_MEMORY_MISSING'
    }

    $repoResults += [PSCustomObject]@{
        Repo = $repoName
        ContextSkill = if ($matchingSkills.Count -gt 0) { ($matchingSkills | Select-Object -ExpandProperty Name) -join ', ' } else { 'NONE' }
        MemoryFiles = if ($memoryFiles.Count -gt 0) { $memoryFiles -join ', ' } else { 'NONE' }
        Status = $status
    }
}

$repoResults | Format-Table -AutoSize

Write-Host "--- Step 4: Managed Target Coverage ---" -ForegroundColor Yellow
$managedTargetResults = @()
$managedTargets = Get-ManagedTargets -WorkspaceMap $workspaceMap -ControlPlane $controlPlane
$nonRepositoryTargets = @($managedTargets | Where-Object { $_.Kind -ne 'repository' -or $_.ContextSurface -eq 'workspace-shell' })

foreach ($target in $nonRepositoryTargets) {
    $targetPath = Join-Path $workspaceRoot $target.Path
    $targetExists = Test-Path $targetPath
    $shellMemoryOk = if ($target.ContextSurface -eq 'workspace-shell') { Test-Path $workspaceShellFile } else { $true }

    $status = if (-not $targetExists) {
        'TARGET_MISSING'
    } elseif (-not $shellMemoryOk) {
        'SHELL_MEMORY_MISSING'
    } else {
        'OK'
    }

    $managedTargetResults += [PSCustomObject]@{
        Target = $target.Name
        Path = $target.Path
        Kind = $target.Kind
        ContextSurface = $target.ContextSurface
        Status = $status
    }
}

if ($managedTargetResults.Count -gt 0) {
    $managedTargetResults | Format-Table -AutoSize
} else {
    Write-Host '  No non-repository managed targets declared.'
}

Write-Host "--- Step 5: MCP Coverage ---" -ForegroundColor Yellow
$requiredServers = @($controlPlane.mcpPolicy.baselineRequired)
$optionalServers = @($controlPlane.mcpPolicy.optional)
$missingRequiredMcp = @()

if (Test-Path $mcpFile) {
    $mcp = Get-Content $mcpFile -Raw | ConvertFrom-Json
    $servers = if ($null -ne $mcp.mcpServers) { @($mcp.mcpServers.PSObject.Properties.Name) } else { @() }

    foreach ($server in $requiredServers) {
        $present = $servers -contains $server
        $color = if ($present) { 'Green' } else { 'Red' }
        $label = if ($present) { 'PRESENT' } else { 'MISSING' }
        Write-Host "  $server : $label" -ForegroundColor $color
        if (-not $present) {
            $missingRequiredMcp += $server
        }
    }

    foreach ($server in $optionalServers) {
        $present = $servers -contains $server
        $color = if ($present) { 'Green' } else { 'Yellow' }
        $label = if ($present) { 'OPTIONAL_PRESENT' } else { 'OPTIONAL_MISSING' }
        Write-Host "  $server : $label" -ForegroundColor $color
    }

    if (Test-Path $mcpRegistryFile) {
        $registry = Get-Content $mcpRegistryFile -Raw | ConvertFrom-Json
        $registryServers = if ($null -ne $registry.servers) { @($registry.servers) } else { @() }
        $registryDiff = Compare-Object -ReferenceObject (@($servers | Sort-Object)) -DifferenceObject (@($registryServers | Sort-Object))
        $registryFresh = ($null -eq $registryDiff -or $registryDiff.Count -eq 0)
        $registryColor = if ($registryFresh) { 'Green' } else { 'Yellow' }
        $registryLabel = if ($registryFresh) { 'CURRENT' } else { 'STALE - rerun bootstrap:ai' }
        Write-Host "  mcp-registry : $registryLabel" -ForegroundColor $registryColor
    }
} else {
    Write-Host '  .vscode/mcp.json not found' -ForegroundColor Red
    $missingRequiredMcp = $requiredServers
}

$coverageIssues = @($repoResults | Where-Object { $_.Status -ne 'OK' })
$managedTargetIssues = @($managedTargetResults | Where-Object { $_.Status -ne 'OK' })

Write-Host "`n=== Readiness Summary ===" -ForegroundColor Cyan
$catalogColor = if ($catalogOk) { 'Green' } else { 'Red' }
$catalogLabel = if ($catalogOk) { 'OK' } else { 'ISSUES FOUND' }
Write-Host "Agent catalog:    $catalogLabel" -ForegroundColor $catalogColor
Write-Host ("Public surface:  " + $(if ($surfaceOk) { 'OK' } else { 'REVIEW NEEDED' })) -ForegroundColor $surfaceColor
$coverageColor = if ($coverageIssues.Count -eq 0) { 'Green' } else { 'Yellow' }
Write-Host "Repo coverage:    $($repoResults.Count - $coverageIssues.Count)/$($repoResults.Count) repos covered" -ForegroundColor $coverageColor
$targetCoverageColor = if ($managedTargetIssues.Count -eq 0) { 'Green' } else { 'Yellow' }
Write-Host "Target coverage:  $($managedTargetResults.Count - $managedTargetIssues.Count)/$($managedTargetResults.Count) non-repo targets covered" -ForegroundColor $targetCoverageColor
$mcpCoverageColor = if ($missingRequiredMcp.Count -eq 0) { 'Green' } else { 'Red' }
Write-Host "MCP baseline:     $(if ($missingRequiredMcp.Count -eq 0) { 'OK' } else { 'MISSING REQUIRED' })" -ForegroundColor $mcpCoverageColor

if (-not $surfaceOk) {
    Write-Host 'Public surface issues:' -ForegroundColor Yellow
    if ($publicAgents.Count -eq 0) {
        Write-Host '  - developer.agent.md and team-lead.agent.md are missing or not public'
    } else {
        Write-Host '  - Public surface must contain exactly developer.agent.md and team-lead.agent.md'
    }
}

if ($coverageIssues.Count -gt 0) {
    Write-Host 'Repo context issues:' -ForegroundColor Yellow
    $coverageIssues | ForEach-Object {
        $detail = $_.Status
        if ($_.ContextSkill -eq 'NONE') {
            $detail += ' | missing context skill'
        }
        if ($_.MemoryFiles -eq 'NONE' -or $_.MemoryFiles -notlike '*recent-changes.md*' -or $_.MemoryFiles -notlike '*dependencies.md*' -or $_.MemoryFiles -notlike '*context.md*') {
            $detail += ' | missing repo memory'
        }
        Write-Host "  - $($_.Repo): $detail"
    }
}

if ($managedTargetIssues.Count -gt 0) {
    Write-Host 'Managed target issues:' -ForegroundColor Yellow
    $managedTargetIssues | ForEach-Object {
        Write-Host "  - $($_.Target): $($_.Status)"
    }
}

if ($missingRequiredMcp.Count -gt 0) {
    Write-Host 'MCP issues:' -ForegroundColor Yellow
    $missingRequiredMcp | ForEach-Object {
        Write-Host "  - missing required MCP: $_"
    }
}

$exitCode = $coverageIssues.Count + $managedTargetIssues.Count + $missingRequiredMcp.Count + $(if ($catalogOk) { 0 } else { 1 }) + $(if ($surfaceOk) { 0 } else { 1 })
exit $exitCode