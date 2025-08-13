$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$stateFile = Join-Path $root 'state/context_state.json'
if (-not (Test-Path $stateFile)) { Write-Error 'No state file'; exit 1 }
$histDir = Join-Path $root 'state/history'
if (-not (Test-Path $histDir)) { New-Item -ItemType Directory -Path $histDir | Out-Null }
$ts = Get-Date -Format 'yyyyMMdd_HHmmss'
Copy-Item -LiteralPath $stateFile -Destination (Join-Path $histDir "context_state_$ts.json") -Force
Write-Host "Snapshot written: context_state_$ts.json"
