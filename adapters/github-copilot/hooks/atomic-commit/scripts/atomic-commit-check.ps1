param(
    [string]$CommitMessageFile = '.git/COMMIT_EDITMSG'
)

$staged = git diff --cached --name-only
$javaStaged = $staged | Where-Object { $_ -match '\.java$' }

Write-Host "[atomic-commit] Checking staged changes..."

if (Test-Path '.\mvnw.cmd') {
    Write-Host "[atomic-commit] Running compilation check..."
    & .\mvnw.cmd compile -q 2>&1 | Out-Host
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[atomic-commit] BLOCKED: Compilation failed. Fix errors before committing." -ForegroundColor Red
        exit 1
    }
}

$testStaged = $staged | Where-Object { $_ -match 'Test\.java$' }
if ($testStaged -and (Test-Path '.\mvnw.cmd')) {
    Write-Host "[atomic-commit] Running test check..."
    & .\mvnw.cmd test -q 2>&1 | Out-Host
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[atomic-commit] BLOCKED: Tests failed. All tests must be green before committing." -ForegroundColor Red
        exit 1
    }
}

if ($javaStaged) {
    Write-Host "[atomic-commit] Checking for entity leaks..."
    foreach ($file in $javaStaged) {
        if ($file -notmatch '[/\\]data[/\\]' -and (Test-Path $file)) {
            $match = Select-String -Path $file -Pattern 'Entity\b' -Quiet -ErrorAction SilentlyContinue
            if ($match) {
                Write-Host "[atomic-commit] WARNING: '$file' may reference an Entity class outside data/ package." -ForegroundColor Yellow
            }
        }
    }
}

if (Test-Path $CommitMessageFile) {
    $msg = Get-Content $CommitMessageFile -First 1
    $pattern = '^(feat|fix|refactor|test|docs|chore|perf|style)(\([a-z0-9-]+\))?: .+'
    if ($msg -notmatch $pattern) {
        Write-Host "[atomic-commit] BLOCKED: Commit message does not follow conventional commit format." -ForegroundColor Red
        Write-Host "  Expected: type(scope): subject"
        Write-Host "  Examples: feat(nominas): add POST endpoint"
        Write-Host "            test(service): add branch coverage for NominaService"
        Write-Host "  Got: $msg"
        exit 1
    }
}

Write-Host "[atomic-commit] All checks passed."