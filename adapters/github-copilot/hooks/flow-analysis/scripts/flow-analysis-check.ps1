param()

$staged = git diff --cached --name-only --diff-filter=ACM
$javaStaged = $staged | Where-Object { $_ -match '\.java$' }

Write-Host "[flow-analysis] Checking staged Java changes..."

if (-not $javaStaged) {
    Write-Host "[flow-analysis] No staged Java files found."
    exit 0
}

if (-not (Get-Command python -ErrorAction SilentlyContinue)) {
    Write-Host "[flow-analysis] Python not found. Skipping advisory analysis."
    exit 0
}

foreach ($file in $javaStaged) {
    if (-not (Test-Path $file)) { continue }
    $className = [System.IO.Path]::GetFileNameWithoutExtension($file)

    if ($file -match 'src/main/java') {
        $sourceRoot = $file.Substring(0, $file.IndexOf('src/main/java')) + 'src/main/java'
    } elseif ($file -match 'src/test/java') {
        $sourceRoot = $file.Substring(0, $file.IndexOf('src/test/java')) + 'src/test/java'
    } else {
        $sourceRoot = Split-Path $file -Parent
    }

    $impactJson = python .ai-devtoolkit/scripts/analyze-java.py impact $sourceRoot $className 2>$null
    if (-not $impactJson) { continue }

    try {
        $parsed = $impactJson | ConvertFrom-Json
        $count = @($parsed).Count
        if ($count -gt 5) {
            Write-Host "[flow-analysis] WARNING: $className has fan-in $count from $sourceRoot" -ForegroundColor Yellow
        }
    } catch {
        continue
    }
}

Write-Host "[flow-analysis] Advisory analysis completed."