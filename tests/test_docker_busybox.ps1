$ErrorActionPreference='Stop'
$util = Join-Path (Split-Path $PSScriptRoot -Parent) 'utils/env_manage.ps1'
if (-not (Test-Path $util)) { throw 'env_manage utility missing' }
function Invoke-Env { param([string[]]$ArgsLine) & pwsh -NoLogo -NoProfile -File $util @ArgsLine; if($LASTEXITCODE -ne 0){ throw "env_manage failed: $($ArgsLine -join ' ')" } }
Write-Host 'Pulling busybox:latest...' -ForegroundColor Cyan
Invoke-Env @('pull','busybox:latest')
Write-Host 'Running busybox echo test...' -ForegroundColor Cyan
$cid = (& pwsh -NoLogo -NoProfile -File $util run busybox:latest echo ok) | Select-Object -First 1
if (-not $cid) { throw 'busybox run did not return container id' }
Write-Host 'Busybox test completed.' -ForegroundColor Green
