<# Phase 3 — Enable systemd and install native Docker Engine (idempotent, no Docker Desktop). #>
$distro='Ubuntu-Dev'
try {
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
        if ($updated -match 'wsl.conf updated') { wsl --shutdown }

        $check = wsl -d $distro -- bash -lc 'command -v docker >/dev/null 2>&1 && docker info --format {{.ServerVersion}} 2>/dev/null' 2>$null
        $needsInstall = $true
        if ($LASTEXITCODE -eq 0 -and $check) { $needsInstall = $false }

docker info >/dev/null 2>&1 || { echo 'Docker engine not responding after install'; exit 2; }
                                                                if ($needsInstall) {
                                                                                                $steps = @(
                                                                                                        'set -e',
                                                                                                        'export DEBIAN_FRONTEND=noninteractive',
                                                                                                        'sudo apt-get update -y',
                                                                                                        'sudo apt-get install -y ca-certificates curl gnupg lsb-release',
                                                                                                        'sudo install -m 0755 -d /etc/apt/keyrings',
                                                                                                        'if [ ! -f /etc/apt/keyrings/docker.gpg ]; then curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg; sudo chmod a+r /etc/apt/keyrings/docker.gpg; fi',
                                                                                                        'codename=$( . /etc/os-release; echo $UBUNTU_CODENAME )',
                                                                                                        'echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $codename stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null',
                                                                                                        'sudo apt-get update -y',
                                                                                                        'sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin',
                                                                                                        'sudo usermod -aG docker $USER || true',
                                                                                                        'sudo systemctl enable docker || true',
                                                                                                        'sudo systemctl restart docker || true',
                                                                                                        'sleep 2',
                                                                                                        'command -v docker >/dev/null 2>&1 || { echo install-missing-docker; exit 2; }',
                                                                                                        'docker info >/dev/null 2>&1 || { echo engine-not-responding; exit 3; }'
                                                                                                )
                                                                                                $joined = ($steps -join ' && ')
                                                                                                $installOut = wsl -d $distro -- bash -lc "$joined" 2>&1
                                                                                                if ($LASTEXITCODE -ne 0) { Write-Error "Docker install failed: $installOut"; exit 1 }
        }

        # Post-install hardening / config (optional: log rotate placeholder)
        $daemonConfig = @'
{
    "log-driver": "json-file",
    "log-opts": { "max-size": "10m", "max-file": "3" },
    "features": { "buildkit": true }
}
'@
        wsl -d $distro -- bash -c "if [ ! -f /etc/docker/daemon.json ]; then echo '$daemonConfig' | sudo tee /etc/docker/daemon.json >/dev/null; sudo systemctl restart docker || true; fi" | Out-Null

                # Final verification with small retry for daemon startup
                $attempt=0; $ok=$false
                while($attempt -lt 5 -and -not $ok){
                        $attempt++
                        $chk = wsl -d $distro -- bash -lc 'command -v docker >/dev/null 2>&1 && docker info --format {{.ServerVersion}} 2>/dev/null || true'
                        if ($chk) { $ok=$true } else { Start-Sleep -Seconds 2 }
                }
                if (-not $ok) { Write-Error 'Docker engine not responding after installation retries.'; exit 1 }
                Write-Output 'Phase 3 completed: systemd enabled and native Docker Engine ensured.'
}
catch {
        Write-Error "Phase 3 error: $($_.Exception.Message)"; exit 1
}
