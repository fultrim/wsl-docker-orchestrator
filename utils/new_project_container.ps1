param(
  [Parameter(Mandatory=$true)][string]$Manifest,
  [Parameter(Mandatory=$true)][string]$ProjectPath
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
if (-not (Test-Path -LiteralPath $Manifest)) { throw "Manifest not found: $Manifest" }
if (-not (Test-Path -LiteralPath $ProjectPath)) { throw "Project path not found: $ProjectPath" }
$raw = Get-Content -Raw -LiteralPath $Manifest | ConvertFrom-Json
$dcDir = Join-Path $ProjectPath '.devcontainer'
if (-not (Test-Path -LiteralPath $dcDir)) { New-Item -ItemType Directory -Path $dcDir | Out-Null }

function Convert-PathForMount($p){
  if ($p -match '^[A-Za-z]:') { return ($p -replace '^([A-Za-z]):','/mnt/$1' -replace '\\','/').ToLower() }
  return $p
}

$base = $raw.base
$customImage = $raw.customImage
$runtimes = $raw.runtimes
$ext = $raw.extensions
$mounts = $raw.mounts
$did = [bool]$raw.dockerInDocker
$extraPkgs = $raw.extraPackages
$postExtra = $raw.postCreate
$envMap = $raw.env
$name = $raw.name

$needsDockerfile = $false
$imageRef = ''

switch ($base) {
  'ubuntu' { $imageRef = 'ubuntu:22.04' }
  'alpine' { $imageRef = 'alpine:3.20' }
  'debian' { $imageRef = 'debian:12-slim' }
  'fedora' { $imageRef = 'fedora:40' }
  'rocky' { $imageRef = 'rockylinux:9' }
  'amazonlinux' { $imageRef = 'amazonlinux:2023' }
  'custom' { $imageRef = $customImage; if (-not $imageRef) { throw 'customImage required when base=custom' } }
  default { throw "Unsupported base: $base" }
}

# Determine if we must layer tooling
if ($runtimes.node -or $runtimes.python -or $runtimes.dotnet -or $runtimes.go -or $extraPkgs) { $needsDockerfile = $true }

$dockerfilePath = Join-Path $dcDir 'Dockerfile'
if ($needsDockerfile) {
  $lines = @()
  $lines += "FROM $imageRef"
  if ($base -match 'ubuntu|debian') { $lines += 'ENV DEBIAN_FRONTEND=noninteractive' }
  if ($base -match 'ubuntu|debian') {
    $lines += 'RUN apt-get update -y && apt-get install -y curl git ca-certificates bash sudo build-essential gnupg lsb-release'
  } elseif ($base -eq 'alpine') {
    $lines += 'RUN apk add --no-cache bash sudo curl git build-base'
  } elseif ($base -eq 'fedora' -or $base -eq 'rocky' -or $base -eq 'amazonlinux') {
    $lines += 'RUN (command -v dnf && dnf -y update && dnf -y install git sudo curl gcc gcc-c++ make which tar gzip ca-certificates || microdnf update -y) || true'
  }
  if ($runtimes.node) {
    if ($base -match 'ubuntu|debian') { $lines += 'RUN curl -fsSL https://deb.nodesource.com/setup_' + $runtimes.node + '.x | bash - && apt-get install -y nodejs' }
    elseif ($base -eq 'alpine') { $lines += 'RUN apk add --no-cache nodejs npm' }
    else { $lines += 'RUN curl -fsSL https://rpm.nodesource.com/setup_' + $runtimes.node + '.x | bash - && (dnf -y install nodejs || yum -y install nodejs)' }
  }
  if ($runtimes.python -and $runtimes.python -ne 'system') {
    if ($base -match 'ubuntu|debian') { $lines += 'RUN apt-get install -y python' + $runtimes.python }
    elseif ($base -eq 'alpine') { $lines += 'RUN apk add --no-cache python' }
  }
  if ($runtimes.dotnet) {
    $lines += 'RUN wget https://dot.net/v1/dotnet-install.sh -O /tmp/dotnet-install.sh && bash /tmp/dotnet-install.sh --channel ' + $runtimes.dotnet + ' --install-dir /usr/share/dotnet && ln -s /usr/share/dotnet/dotnet /usr/bin/dotnet'
  }
  if ($runtimes.go) {
    $lines += 'RUN curl -fsSL https://go.dev/dl/go' + $runtimes.go +'.linux-amd64.tar.gz -o /tmp/go.tgz && tar -C /usr/local -xzf /tmp/go.tgz && ln -s /usr/local/go/bin/go /usr/bin/go'
  }
  if ($extraPkgs) {
    if ($base -match 'ubuntu|debian') { $lines += 'RUN apt-get install -y ' + ($extraPkgs -join ' ') }
    elseif ($base -eq 'alpine') { $lines += 'RUN apk add --no-cache ' + ($extraPkgs -join ' ') }
    else { $lines += 'RUN (dnf -y install ' + ($extraPkgs -join ' ') + ' || yum -y install ' + ($extraPkgs -join ' ') + ')' }
  }
  $lines += "RUN useradd -m dev && echo 'dev ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/90-dev"
  $lines += 'USER dev'
  $lines += 'WORKDIR /workspace'
  Set-Content -LiteralPath $dockerfilePath -Value ($lines -join "`n") -Encoding UTF8
}

# Build devcontainer.json
$devJson = [ordered]@{}
$devJson.name = $name
if ($needsDockerfile) {
  $devJson.build = @{ dockerfile = 'Dockerfile' }
} else {
  $devJson.image = $imageRef
}
if ($did) { $devJson.features = @{ 'ghcr.io/devcontainers/features/docker-in-docker:2' = @{} } }
if ($ext) { $devJson.customizations = @{ vscode = @{ extensions = @($ext) } } }
$devJson.remoteUser = 'dev'

# Mounts
if ($mounts) {
  $devJson.mounts = @()
  foreach ($m in $mounts) {
    $src = $m.source
    $tgt = $m.target
    $ro = $m.readOnly
  # Preserve original host path for Docker bind (Docker Desktop/WSL can interpret Windows path); optionally convert
  $mountStr = "source=$src,target=$tgt,type=bind"
    if ($ro) { $mountStr += ',readonly' }
    $devJson.mounts += $mountStr
  }
}

# Post create script
$postLines = @("echo 'Base container ready'", "id -u && uname -a")
if ($postExtra) { $postLines += $postExtra }
$devJson.postCreateCommand = ($postLines -join ' && ')

if ($envMap) { $devJson.containerEnv = $envMap }

$devPath = Join-Path $dcDir 'devcontainer.json'
($devJson | ConvertTo-Json -Depth 6) | Set-Content -LiteralPath $devPath -Encoding UTF8

# Smoke test script
$smoke = @('#!/usr/bin/env bash','set -e','echo "Runtime versions:"','command -v node && node --version || true','command -v python3 && python3 --version || true','command -v dotnet && dotnet --info | head -n 20 || true','command -v go && go version || true','echo OK') -join "`n"
Set-Content -LiteralPath (Join-Path $dcDir 'test-smoke.sh') -Value $smoke -Encoding UTF8

Write-Host "Generated devcontainer in $dcDir" -ForegroundColor Green
