param(
  [Parameter(Mandatory=$true)][string]$ProjectPath,
  [string]$Manifest = '',
  [switch]$OpenCode,
  [switch]$ForceRegenerate
)
<#!
Automated project environment bootstrap (host autonomous entry point).
- Ensures Docker engine present & running in Ubuntu-Dev.
- Generates/updates .devcontainer from manifest (or example) via new_project_container.ps1.
- Optionally opens VS Code (Remote WSL) at project path.
Usage:
  pwsh ./wsl_docker_setup/auto_project_env.ps1 -ProjectPath D:\Work\Proj1 -Manifest D:\proj1.manifest.json -OpenCode
!#>
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'

function Convert-ToWslPath([string]$p){ ($p -replace '^([A-Za-z]):','/mnt/$1' -replace '\\','/').ToLower() }

if (-not (Test-Path -LiteralPath $ProjectPath)) { throw "ProjectPath not found: $ProjectPath" }
if (-not $Manifest) { $Manifest = Join-Path (Split-Path -Parent $PSCommandPath) '..' | Join-Path -ChildPath 'project_container.manifest.example.json' }
if (-not (Test-Path -LiteralPath $Manifest)) { throw "Manifest not found: $Manifest" }

$devDir = Join-Path $ProjectPath '.devcontainer'
$generator = Join-Path (Split-Path -Parent $PSCommandPath) 'utils' | Join-Path -ChildPath 'new_project_container.ps1'
$ensureDocker = Join-Path (Split-Path -Parent $PSCommandPath) 'utils' | Join-Path -ChildPath 'ensure_host_docker.ps1'
$fixDocker = Join-Path (Split-Path -Parent $PSCommandPath) 'utils' | Join-Path -ChildPath 'fix_docker_install.ps1'

Write-Host '[1] Verifying docker CLI inside WSL...' -ForegroundColor Cyan
$dockerCheck = & wsl -d Ubuntu-Dev bash -lc 'command -v docker >/dev/null 2>&1; echo $?'
if ($dockerCheck -ne 0) {
  Write-Warning 'Docker CLI missing – attempting install.'
  pwsh $fixDocker
}

Write-Host '[2] Ensuring host docker daemon running...' -ForegroundColor Cyan
pwsh $ensureDocker | Out-Null

Write-Host '[3] Generating devcontainer (if needed)...' -ForegroundColor Cyan
$regen = $false
if ($ForceRegenerate -or -not (Test-Path -LiteralPath $devDir)) { $regen = $true }
else {
  $devJson = Join-Path $devDir 'devcontainer.json'
  if (-not (Test-Path -LiteralPath $devJson)) { $regen = $true }
  else {
    $manifestTime = (Get-Item -LiteralPath $Manifest).LastWriteTimeUtc
    $devTime = (Get-Item -LiteralPath $devJson).LastWriteTimeUtc
    if ($manifestTime -gt $devTime) { $regen = $true }
  }
}
if ($regen) {
  pwsh $generator -Manifest $Manifest -ProjectPath $ProjectPath
  Write-Host 'Devcontainer (re)generated.' -ForegroundColor Green
} else {
  Write-Host 'Devcontainer up-to-date.' -ForegroundColor DarkGray
}

Write-Host '[4] Validating docker accessibility from host WSL...' -ForegroundColor Cyan
$info = & wsl -d Ubuntu-Dev bash -lc 'docker info --format "{{.ServerVersion}}" 2>/dev/null' 2>$null
if (-not $info) { Write-Warning 'Docker daemon not reachable. Container tools may not detect it.' } else { Write-Host "Docker server version: $info" -ForegroundColor Green }

if ($OpenCode) {
  Write-Host '[5] Launching VS Code in WSL...' -ForegroundColor Cyan
  $wslPath = Convert-ToWslPath (Resolve-Path -LiteralPath $ProjectPath).Path
  & wsl -d Ubuntu-Dev bash -lc "cd $wslPath && code ." | Out-Null
}

Write-Host 'Autonomous project environment preparation complete.' -ForegroundColor Green
