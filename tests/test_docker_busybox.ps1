$ErrorActionPreference='Stop'
$util = Join-Path (Split-Path $PSScriptRoot -Parent) 'utils/env_manage.ps1'
if (-not (Test-Path $util)) { throw 'env_manage utility missing' }
function Invoke-Env { param([string[]]$ArgsLine) & pwsh -NoLogo -NoProfile -File $util @ArgsLine; if($LASTEXITCODE -ne 0){ throw "env_manage failed: $($ArgsLine -join ' ')" } }
Write-Host 'Pulling busybox:latest...' -ForegroundColor Cyan
Invoke-Env @('pull','busybox:latest')
Write-Host 'Running busybox detached container (sleep)...' -ForegroundColor Cyan
$cid = (wsl -d Ubuntu-Dev -- bash -lc "docker run -d busybox:latest sh -c 'sleep 30'") 2>$null | Select-Object -First 1
if (-not $cid -or $cid -notmatch '^[0-9a-f]{12,}') { throw "busybox run did not return container id (got '$cid')" }
Write-Host "Container id: $cid" -ForegroundColor DarkGray
Write-Host 'Executing echo inside container...' -ForegroundColor Cyan
$output = wsl -d Ubuntu-Dev -- bash -lc "docker exec $cid sh -c 'echo ok'" 2>$null
if ($output -notmatch '^ok') { throw "unexpected busybox exec output: $output" }
Write-Host "  $output" -ForegroundColor DarkGray
wsl -d Ubuntu-Dev -- bash -lc "docker rm -f $cid" | Out-Null
Write-Host 'Busybox test completed.' -ForegroundColor Green
