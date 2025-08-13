<#
 Phase 3 — Ensure systemd enabled and a working Docker Engine is available.
 Enhancements:
  * Detect Docker Desktop integration and skip native install if present.
  * Remain idempotent: if either native engine OR Desktop provides a responsive socket, do nothing.
  * Provide explicit messaging so users know which engine is active.
#>
$distro='Ubuntu-Dev'
try {
        Write-Host '[Phase3] Starting systemd + Docker verification...' -ForegroundColor Cyan

        # 1. Ensure systemd flag present
        $confScript = @'
set -e
sudo mkdir -p /etc
if ! grep -qi '^systemd=true' /etc/wsl.conf 2>/dev/null; then
        sudo tee /etc/wsl.conf > /dev/null <<'EOF'
[boot]
systemd=true
EOF
        echo 'wsl.conf updated; will require WSL restart.'
fi
'@
        $updated = wsl -d $distro -- bash -c "$confScript" 2>&1
        if ($updated -match 'wsl.conf updated') { Write-Host '[Phase3] systemd flag added; issuing wsl --shutdown' -ForegroundColor Yellow; wsl --shutdown }

        # 2. Detect existing working docker (either native or Desktop integration)
        $dockerProbe = wsl -d $distro -- bash -lc 'command -v docker >/dev/null 2>&1 && docker info --format {{.ServerVersion}} 2>/dev/null || true'
        $desktopMarker = wsl -d $distro -- bash -lc '[ -d /mnt/wsl/docker-desktop ] && echo dd || true'
        $engineType = $null
        if ($dockerProbe) {
                if ($desktopMarker -eq 'dd') { $engineType = 'desktop' } else { $engineType = 'native' }
        }

        if ($engineType) {
                Write-Host "[Phase3] Detected existing Docker Engine ($engineType). Skipping native install." -ForegroundColor Green
        }

        $needsInstall = -not $engineType
        if ($needsInstall) {
                Write-Host '[Phase3] No engine detected; proceeding with native install...' -ForegroundColor Yellow
                $helper = Join-Path (Split-Path $PSScriptRoot -Parent) 'utils/fix_docker_install.ps1'
                if (-not (Test-Path $helper)) { Write-Error 'Missing fix_docker_install.ps1 utility'; exit 1 }
                & $helper
                if ($LASTEXITCODE -ne 0) { Write-Error 'Docker install helper failed'; exit 1 }
                $engineType = 'native'
        }

        # 3. Optional daemon.json only for native (avoid clobbering Desktop managed config)
        if ($engineType -eq 'native') {
                $daemonConfig = @'
{
        "log-driver": "json-file",
        "log-opts": { "max-size": "10m", "max-file": "3" },
        "features": { "buildkit": true }
}
'@
                wsl -d $distro -- bash -c "if [ ! -f /etc/docker/daemon.json ]; then echo '$daemonConfig' | sudo tee /etc/docker/daemon.json >/dev/null; sudo systemctl restart docker || true; fi" | Out-Null
        }

        # 4. Final verification with retry
        $attempt=0; $ok=$false
        while($attempt -lt 6 -and -not $ok){
                $attempt++
                $chk = wsl -d $distro -- bash -lc 'command -v docker >/dev/null 2>&1 && docker info --format {{.ServerVersion}} 2>/dev/null || true'
                if ($chk) { $ok=$true } else { Start-Sleep -Seconds 2 }
        }
        if (-not $ok) { Write-Error 'Docker engine not responding after retries.'; exit 1 }
        Write-Output "Phase 3 completed: systemd enabled and Docker Engine available ($engineType)."
}
catch {
        Write-Error "Phase 3 error: $($_.Exception.Message)"; exit 1
}
