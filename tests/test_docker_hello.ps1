$ErrorActionPreference='Stop'
$util = Join-Path (Split-Path $PSScriptRoot -Parent) 'utils/env_manage.ps1'
if (-not (Test-Path $util)) { throw 'env_manage utility missing' }
function Invoke-Env {
	param([Parameter(Mandatory)][string[]]$ArgsLine)
	Write-Host "=> env_manage.ps1 $($ArgsLine -join ' ')" -ForegroundColor DarkGray
	& pwsh -NoLogo -NoProfile -File $util @ArgsLine
	if ($LASTEXITCODE -ne 0){ throw "Command failed: $($ArgsLine -join ' ')" }
}
Write-Host 'Pulling hello-world image...' -ForegroundColor Cyan
Invoke-Env @('pull','hello-world')
Write-Host 'Running hello-world container...' -ForegroundColor Cyan
Invoke-Env @('run','hello-world')
Write-Host 'Listing containers...' -ForegroundColor Cyan
Invoke-Env @('docker-ps') | Out-Null
Write-Host 'Docker hello-world test completed.' -ForegroundColor Green
