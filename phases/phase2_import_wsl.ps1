<#
Phase 2 — Baseline Import (Jammy preferred) with fallback logic, idempotent.
Required success lines:
 Selected baseline: <path>
 Ubuntu-Dev import complete (Jammy preferred). (or already present message)
 Phase 2 completed: Baseline present and Ubuntu-Dev (Jammy) registered.
#>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$distroName = 'Ubuntu-Dev'
$installRoot = 'D:\\WSL'
$distroPath = Join-Path $installRoot $distroName
$baselineDir = 'K:\\Baselines\\WSL'
if (-not (Test-Path -LiteralPath $baselineDir)) { New-Item -ItemType Directory -Path $baselineDir -Force | Out-Null }
$candidates = @(
    'ubuntu-22.04-export.tar',
    'ubuntu-jammy-wsl-amd64-ubuntu22.04lts.rootfs.tar.gz',
    'ubuntu-jammy-wsl-amd64-wsl.rootfs.tar.gz', # legacy name fallback
    'ubuntu-24.04-export.tar',
    'ubuntu-noble-wsl-amd64-ubuntu24.04lts.rootfs.tar.gz',
    'ubuntu-noble-wsl-amd64-wsl.rootfs.tar.gz'
)
$urlJammy = 'https://cloud-images.ubuntu.com/wsl/jammy/current/ubuntu-jammy-wsl-amd64-ubuntu22.04lts.rootfs.tar.gz'
$urlNoble = 'https://cloud-images.ubuntu.com/wsl/noble/current/ubuntu-noble-wsl-amd64-ubuntu24.04lts.rootfs.tar.gz'
function Download-IfMissing($url,$dest){ if (Test-Path -LiteralPath $dest){return}; Write-Host "Downloading: $url"; Invoke-WebRequest -Uri $url -OutFile $dest -UseBasicParsing; if ((Get-Item $dest).Length -lt 50MB){throw "Downloaded file too small: $dest"} }
try {
 wsl --set-default-version 2 | Out-Null
 $selected = $null
 foreach($c in $candidates){ $p = Join-Path $baselineDir $c; if (Test-Path -LiteralPath $p){ $selected=$p; break } }
 if(-not $selected){
        try { $jam = Join-Path $baselineDir 'ubuntu-jammy-wsl-amd64-ubuntu22.04lts.rootfs.tar.gz'; Download-IfMissing $urlJammy $jam; $selected=$jam }
        catch { Write-Warning $_; $nob = Join-Path $baselineDir 'ubuntu-noble-wsl-amd64-ubuntu24.04lts.rootfs.tar.gz'; Download-IfMissing $urlNoble $nob; $selected=$nob }
 }
 Write-Output ("Selected baseline: {0}" -f $selected)
 $exists = (wsl --list --quiet 2>$null) -contains $distroName
 $needsImport = $true
 if ($exists){
        $osr = wsl.exe -d $distroName -- sh -lc '. /etc/os-release; echo $VERSION_ID;$VERSION_CODENAME' 2>$null
     $parts = ($osr | Out-String).Trim().Split("`n")
     if (($parts -join ' ') -match '22.04|jammy'){ $needsImport = $false }
     else {
         $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
         $backup = Join-Path $baselineDir ("Ubuntu-Dev-backup_{0}.tar" -f $stamp)
         Write-Host ("Exporting existing non-jammy distro -> {0}" -f $backup)
         wsl --export $distroName $backup
         wsl --unregister $distroName
     }
 }
 if ($needsImport){ if (-not (Test-Path -LiteralPath $distroPath)) { New-Item -ItemType Directory -Path $distroPath -Force | Out-Null }; wsl --import $distroName $distroPath $selected --version 2; wsl -s $distroName | Out-Null; Write-Output 'Ubuntu-Dev import complete (Jammy preferred).' } else { wsl -s $distroName | Out-Null; Write-Output 'Ubuntu-Dev already present (Jammy).' }
 Write-Output 'Phase 2 completed: Baseline present and Ubuntu-Dev (Jammy) registered.'
}
catch { Write-Error ("Phase 2 error: {0}" -f $_.Exception.Message); exit 1 }
