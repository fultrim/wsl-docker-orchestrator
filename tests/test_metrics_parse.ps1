$ErrorActionPreference='Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$base = Split-Path $root
$start = Join-Path $base 'start_setup.ps1'
$stateDir = Join-Path $base 'state'
$metrics = Join-Path $stateDir 'metrics_history.csv'
if (-not (Test-Path $metrics)) {
  Write-Host 'metrics_history.csv absent; running start_setup to generate one...' -ForegroundColor Yellow
  & $start -AutoAll
}
if (-not (Test-Path $metrics)) { throw 'metrics_history.csv still missing after setup run' }
$collect = Join-Path (Join-Path $base 'utils') 'collect_metrics.ps1'
if (-not (Test-Path $collect)) { throw 'collect_metrics utility missing' }
& pwsh -NoLogo -NoProfile -File $collect | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'collect_metrics exited non-zero' }
Write-Host 'Metrics parse test completed.' -ForegroundColor Green
