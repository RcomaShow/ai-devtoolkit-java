param(
	[switch]$ShowConfiguration
)

$workspaceRoot = Split-Path -Parent $PSScriptRoot
$envFile = Join-Path $workspaceRoot '.vscode\.env'
$jsonEnvFile = Join-Path $workspaceRoot '.vscode\mcp.env.json'

function Set-ProcessEnvironmentValue {
	param(
		[string]$Name,
		[string]$Value
	)

	[Environment]::SetEnvironmentVariable($Name, $Value, 'Process')
}

function Import-DotEnvFile {
	param(
		[string]$Path
	)

	if (-not (Test-Path $Path)) {
		return $false
	}

	Get-Content -Path $Path | ForEach-Object {
		$line = $_.Trim()
		if (-not $line -or $line.StartsWith('#')) {
			return
		}

		if ($line -match '^(?<name>[A-Za-z_][A-Za-z0-9_]*)=(?<value>.*)$') {
			$name = $matches['name']
			$value = $matches['value'].Trim()
			if (($value.StartsWith('"') -and $value.EndsWith('"')) -or ($value.StartsWith("'") -and $value.EndsWith("'"))) {
				if ($value.Length -ge 2) {
					$value = $value.Substring(1, $value.Length - 2)
				}
			}

			Set-ProcessEnvironmentValue -Name $name -Value $value
		}
	}

	return $true
}

function Import-JsonEnvFile {
	param(
		[string]$Path,
		[string]$SectionName
	)

	if (-not (Test-Path $Path)) {
		return $false
	}

	try {
		$configuration = Get-Content -Path $Path -Raw | ConvertFrom-Json
	} catch {
		throw "Failed to parse JSON environment file '$Path': $($_.Exception.Message)"
	}

	$section = $configuration.PSObject.Properties[$SectionName]
	$source = $configuration
	if ($null -ne $section -and $section.Value -is [System.Management.Automation.PSCustomObject]) {
		$source = $section.Value
	}

	foreach ($property in $source.PSObject.Properties) {
		if ($null -eq $property.Value) {
			continue
		}

		if ($property.Value -is [System.Management.Automation.PSCustomObject]) {
			continue
		}

		Set-ProcessEnvironmentValue -Name $property.Name -Value ([string]$property.Value)
	}

	return $true
}

function Import-OracleEnvironment {
	param(
		[string]$LegacyEnvPath,
		[string]$JsonEnvPath
	)

	$loadedSources = @()
	if (Import-DotEnvFile -Path $LegacyEnvPath) {
		$loadedSources += $LegacyEnvPath
	}

	if (Import-JsonEnvFile -Path $JsonEnvPath -SectionName 'oracle-official') {
		$loadedSources += $JsonEnvPath
	}

	return $loadedSources
}


function Get-SqlclRoot {
	$sqlCommand = Get-Command sql -ErrorAction SilentlyContinue
	if ($null -ne $sqlCommand) {
		$commandPath = $sqlCommand.Source
		if (-not $commandPath) {
			$commandPath = $sqlCommand.Path
		}

		if ($commandPath) {
			return Split-Path -Parent (Split-Path -Parent $commandPath)
		}
	}

	$extensionRoot = Join-Path $env:USERPROFILE '.vscode\extensions'
	if (Test-Path $extensionRoot) {
		$sqlclCandidate = Get-ChildItem -Path $extensionRoot -Directory -Filter 'oracle.sql-developer-*' |
			Sort-Object LastWriteTime -Descending |
			ForEach-Object {
				Join-Path $_.FullName 'dbtools\sqlcl'
			} |
			Where-Object { Test-Path $_ } |
			Select-Object -First 1

		if ($sqlclCandidate) {
			return $sqlclCandidate
		}
	}

	foreach ($candidate in @(
		'C:\oracle\sqlcl',
		'C:\Program Files\Oracle\SQLcl',
		'C:\Program Files (x86)\Oracle\SQLcl'
	)) {
		if (Test-Path $candidate) {
			return $candidate
		}
	}

	throw 'SQLcl installation not found. Install SQLcl or make the extension-bundled distribution available.'
}

function Get-JavaExecutable {
	if ($env:JAVA_HOME) {
		$candidate = Join-Path $env:JAVA_HOME 'bin\java.exe'
		if (Test-Path $candidate) {
			return $candidate
		}
	}

	$javaCommand = Get-Command java -ErrorAction SilentlyContinue
	if ($null -ne $javaCommand) {
		if ($javaCommand.Source) {
			return $javaCommand.Source
		}

		if ($javaCommand.Path) {
			return $javaCommand.Path
		}
	}

	throw 'Java executable not found. Install a JDK 17+ or set JAVA_HOME before starting the MCP server.'
}

$loadedEnvironmentSources = Import-OracleEnvironment -LegacyEnvPath $envFile -JsonEnvPath $jsonEnvFile

$sqlclRoot = Get-SqlclRoot
$javaExecutable = Get-JavaExecutable
$launchPath = Join-Path $sqlclRoot 'launch'
$connectionString = [Environment]::GetEnvironmentVariable('MCP_DB_CONNECTION', 'Process')

if ([string]::IsNullOrWhiteSpace($connectionString)) {
	throw "MCP_DB_CONNECTION is not set. Populate $jsonEnvFile (preferred) or $envFile before starting the MCP server."
}

if ($ShowConfiguration) {
	Write-Output "sql=$sqlclRoot"
	Write-Output "java=$javaExecutable"
	Write-Output "launch=$launchPath"
	Write-Output "envFile=$envFile"
	Write-Output "jsonEnvFile=$jsonEnvFile"
	Write-Output ("envSources=" + ($(if ($loadedEnvironmentSources.Count -gt 0) { $loadedEnvironmentSources -join ',' } else { 'none' })))
	Write-Output 'mcpDbConnection=set'
	exit 0
}

Set-Location -Path $workspaceRoot
if (-not (Test-Path $launchPath)) {
	throw "SQLcl launch directory not found at $launchPath"
}

& $javaExecutable `
	'--add-modules' 'ALL-DEFAULT' `
	'--add-opens' 'java.prefs/java.util.prefs=oracle.dbtools.win32' `
	'--add-opens' 'jdk.security.auth/com.sun.security.auth.module=oracle.dbtools.win32' `
	'-Djava.net.useSystemProxies=true' `
	'-p' $launchPath `
	'-m' 'oracle.dbtools.sqlcl.app' `
	'-mcp'
exit $LASTEXITCODE