param(
    [string]$Repo = "all"
)

$workspaceRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..\..\..')
$agentsDir     = Join-Path $workspaceRoot '.github\agents'
$skillsDir     = Join-Path $workspaceRoot '.github\skills'
$inventoryFile = Join-Path $workspaceRoot '.ai\memory\workspace-map.json'

function Get-RepositoryNames {
    param(
        [string]$TargetRepo,
        [string]$InventoryPath,
        [string]$RootPath
    )

    if ($TargetRepo -ne 'all') {
        return @($TargetRepo)
    }

    if (Test-Path $InventoryPath) {
        $workspaceMap = Get-Content $InventoryPath -Raw | ConvertFrom-Json
        if ($null -ne $workspaceMap.repositories) {
            return @($workspaceMap.repositories | ForEach-Object { $_.path })
        }
    }

    return @(Get-ChildItem $RootPath -Directory |
        Where-Object { Test-Path (Join-Path $_.FullName '.git') } |
        Select-Object -ExpandProperty Name)
}

Write-Host "`n=== Project Bootstrap -- Phase 2 ===" -ForegroundColor Cyan
Write-Host "Workspace: $workspaceRoot`n"

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
$targets = Get-RepositoryNames -TargetRepo $Repo -InventoryPath $inventoryFile -RootPath $workspaceRoot
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
        Repo         = $repoName
        ContextSkill = if ($matchingSkills.Count -gt 0) { ($matchingSkills | Select-Object -ExpandProperty Name) -join ', ' } else { 'NONE' }
        MemoryFiles  = if ($memoryFiles.Count -gt 0) { $memoryFiles -join ', ' } else { 'NONE' }
        Status       = $status
    }
}

$repoResults | Format-Table -AutoSize

Write-Host "--- Step 4: MCP Coverage ---" -ForegroundColor Yellow
$mcpFile = Join-Path $workspaceRoot '.vscode\mcp.json'
if (Test-Path $mcpFile) {
    $mcp = Get-Content $mcpFile -Raw | ConvertFrom-Json
    $servers = $mcp.mcpServers.PSObject.Properties.Name
    foreach ($server in @('oracle-official', 'bitbucket-corporate')) {
        $present = $servers -contains $server
        $color = if ($present) { 'Green' } else { 'Red' }
        $label = if ($present) { 'PRESENT' } else { 'MISSING' }
        Write-Host "  $server : $label" -ForegroundColor $color
    }
} else {
    Write-Host '  .vscode/mcp.json not found' -ForegroundColor Red
}

$coverageIssues = @($repoResults | Where-Object { $_.Status -ne 'OK' })

Write-Host "`n=== Readiness Summary ===" -ForegroundColor Cyan
$catalogColor = if ($catalogOk) { 'Green' } else { 'Red' }
$catalogLabel = if ($catalogOk) { 'OK' } else { 'ISSUES FOUND' }
Write-Host "Agent catalog:    $catalogLabel" -ForegroundColor $catalogColor
Write-Host ("Public surface:  " + $(if ($surfaceOk) { 'OK' } else { 'REVIEW NEEDED' })) -ForegroundColor $surfaceColor
$coverageColor = if ($coverageIssues.Count -eq 0) { 'Green' } else { 'Yellow' }
Write-Host "Repo coverage:    $($repoResults.Count - $coverageIssues.Count)/$($repoResults.Count) repos covered" -ForegroundColor $coverageColor

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

$exitCode = $coverageIssues.Count + $(if ($catalogOk) { 0 } else { 1 }) + $(if ($surfaceOk) { 0 } else { 1 })
exit $exitCode