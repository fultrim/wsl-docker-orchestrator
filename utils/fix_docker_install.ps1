${ErrorActionPreference='Stop'}
Write-Host 'Ensuring native Docker Engine inside Ubuntu-Dev...' -ForegroundColor Cyan

# Use a single-quoted here-string so all $ are preserved for bash evaluation
$bashScript = @'
set -e
export DEBIAN_FRONTEND=noninteractive
arch=$(dpkg --print-architecture)
codename=$( . /etc/os-release; echo $UBUNTU_CODENAME )

# Prepare keyring & clean any previous malformed docker.list
sudo install -m 0755 -d /etc/apt/keyrings
if [ ! -f /etc/apt/keyrings/docker.gpg ]; then
	curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
	sudo chmod a+r /etc/apt/keyrings/docker.gpg
fi
sudo rm -f /etc/apt/sources.list.d/docker.list
echo "deb [arch=$arch signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $codename stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update -y
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Add current user to docker group (may require new login for non-root user; still proceed)
sudo usermod -aG docker $USER || true

# Enable & start service (systemd should be active already)
sudo systemctl enable docker || true
sudo systemctl restart docker || true

# Basic verification
docker info --format "{{.ServerVersion}}" || exit 5
'@

($bashScript) | & wsl -d Ubuntu-Dev bash -lc 'cat > /tmp/install_docker.sh; chmod +x /tmp/install_docker.sh; bash /tmp/install_docker.sh'
if ($LASTEXITCODE -ne 0) { Write-Error "Docker install/verify failed with code $LASTEXITCODE"; exit 1 }
Write-Host 'Docker Engine present.' -ForegroundColor Green
