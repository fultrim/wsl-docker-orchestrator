param(
  [string]$Distro='Ubuntu-Dev',
  [string]$ProxyDir='D:\wsl_docker_setup\win-docker-proxy',
  [switch]$SetPath,
  [switch]$Force
)
<#!
Installs lightweight Windows docker CLI proxy that forwards commands into WSL distro's docker engine.
Gives Windows VS Code / tools a 'docker' executable without Docker Desktop.

Creates docker.cmd and docker-compose.cmd (compose v2 via 'docker compose').

Usage:
  pwsh ./wsl_docker_setup/utils/install_windows_docker_proxy.ps1 -SetPath
After installation open a new terminal: docker version
!#>
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest

if (-not (Test-Path -LiteralPath $ProxyDir)) { New-Item -ItemType Directory -Path $ProxyDir -Force | Out-Null }

$dockerCmd = @"
@echo off
wsl -d %Distro% docker %* 2>&1
set EXITCODE=%ERRORLEVEL%
exit /b %EXITCODE%
"@ -replace '%Distro%', $Distro

$composeCmd = @"
@echo off
wsl -d %Distro% docker compose %* 2>&1
set EXITCODE=%ERRORLEVEL%
exit /b %EXITCODE%
"@ -replace '%Distro%', $Distro

$dockerPath = Join-Path $ProxyDir 'docker.cmd'
$composePath = Join-Path $ProxyDir 'docker-compose.cmd'
if (-not (Test-Path $dockerPath) -or $Force) { Set-Content -LiteralPath $dockerPath -Value $dockerCmd -Encoding ASCII }
if (-not (Test-Path $composePath) -or $Force) { Set-Content -LiteralPath $composePath -Value $composeCmd -Encoding ASCII }

if ($SetPath) {
  $current = [Environment]::GetEnvironmentVariable('Path','User')
  $escaped = $ProxyDir.Replace('\','\\')
  if ($current -notlike "*$escaped*") {
    $new = ($current.TrimEnd(';') + ';' + $ProxyDir).Trim(';')
    [Environment]::SetEnvironmentVariable('Path',$new,'User')
    Write-Host "Appended $ProxyDir to User PATH (new shells will see it)" -ForegroundColor Green
  } else { Write-Host 'Proxy directory already on PATH.' -ForegroundColor DarkGray }
}

Write-Host "Docker proxy installed at $ProxyDir" -ForegroundColor Green
