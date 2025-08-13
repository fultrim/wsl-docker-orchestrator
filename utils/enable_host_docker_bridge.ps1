param(
  [switch]$InsecureTcp2375
)
$ErrorActionPreference='Stop'
Write-Host 'Configuring Docker host bridge (optional)...' -ForegroundColor Cyan
if ($InsecureTcp2375) {
  $daemonPatch = '{"hosts":["unix:///var/run/docker.sock","tcp://127.0.0.1:2375"]}'
  & wsl -d Ubuntu-Dev bash -lc "echo '$daemonPatch' | sudo tee /etc/docker/daemon.json > /dev/null; sudo systemctl restart docker || true"
  if ($LASTEXITCODE -ne 0) { Write-Warning 'Failed to enable tcp://127.0.0.1:2375'; exit 1 }
  Write-Host 'Enabled tcp://127.0.0.1:2375 (UNSECURED, local only). Set DOCKER_HOST=tcp://127.0.0.1:2375 in Windows if desired.' -ForegroundColor Yellow
} else {
  Write-Host 'No changes (re-run with -InsecureTcp2375 to expose local TCP).' -ForegroundColor DarkGray
}
