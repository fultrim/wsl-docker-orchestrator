$ErrorActionPreference='Stop'
Write-Host 'Ensuring host (WSL) Docker daemon is up...' -ForegroundColor Cyan
$timeout = [TimeSpan]::FromSeconds(40)
$start = Get-Date
while ((Get-Date) - $start -lt $timeout) {
  & wsl -d Ubuntu-Dev bash -lc 'systemctl is-active docker >/dev/null 2>&1 || (sudo systemctl start docker 2>/dev/null || true); if systemctl is-active docker >/dev/null 2>&1 && [ -S /var/run/docker.sock ]; then echo ready; exit 0; fi; echo waiting' | Out-Null
  if ($LASTEXITCODE -eq 0) { Write-Host 'Docker ready.' -ForegroundColor Green; exit 0 }
  Start-Sleep -Seconds 2
}
Write-Warning 'Docker daemon not confirmed ready before timeout.'
