param([switch]$Raw)
$statePath = Join-Path (Split-Path $MyInvocation.MyCommand.Path -Parent) 'state/context_state.json'
if (-not (Test-Path $statePath)) { Write-Error 'State file missing'; exit 1 }
if ($Raw) { Get-Content -Raw $statePath | Write-Output; exit 0 }
$state = Get-Content -Raw $statePath | ConvertFrom-Json
Write-Host '=== Orchestrator State Summary ==='
Write-Host ("Phases: " + ($state.phases.PSObject.Properties | ForEach-Object { "{0}:{1}" -f $_.Name, $_.Value.status } -join ', '))
if ($state.distro.name) { Write-Host ("Distro: {0} {1} kernel={2}" -f $state.distro.name,$state.distro.version,$state.distro.kernel) }
if ($state.docker.serverVersion) { Write-Host ("Docker: v{0}" -f $state.docker.serverVersion) }
if ($state.health.drives) {
  $driveSumm = $state.health.drives | ForEach-Object { $pct = if ($_.totalBytes -gt 0){ [math]::Round(100 - (($_.freeBytes*100.0)/$_.totalBytes),1) } else { 0 }; "{0}:{1}%" -f $_.name,$pct }
  Write-Host ("Drives Used%: " + ($driveSumm -join ' '))
  Write-Host ("VHDX: {0:N2} GB" -f ($state.health.vhdxBytes/1GB))
}
