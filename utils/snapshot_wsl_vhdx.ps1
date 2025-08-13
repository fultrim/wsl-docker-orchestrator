<#!
Snapshot the WSL Ubuntu-Dev ext4.vhdx (and optional export) to K:\WSL\Snapshots.

Features:
 - Safe copy of ext4.vhdx (optionally after terminating the distro)
 - Optional wsl --export to a compressed .tar.gz (requires gzip if available in PATH or inside WSL)
 - Retains a configurable number of snapshots (FIFO pruning)

Usage Examples:
  ./utils/snapshot_wsl_vhdx.ps1             # simple copy of ext4.vhdx
  ./utils/snapshot_wsl_vhdx.ps1 -Terminate  # terminate distro before copying (consistent state)
  ./utils/snapshot_wsl_vhdx.ps1 -ExportTar  # also produce Ubuntu-Dev_YYYYMMDD_HHMMSS.tar (raw)
  ./utils/snapshot_wsl_vhdx.ps1 -ExportTar -CompressTar
  ./utils/snapshot_wsl_vhdx.ps1 -Retain 5   # keep only 5 most recent copies

NOTE: A perfectly consistent filesystem snapshot is best achieved via `wsl --terminate <distro>` before copy.
If -Terminate is not used the copy still usually works (sparse VHDX copy) but may reflect in-flight changes.
!#>
param(
    [string]$DistroName = 'Ubuntu-Dev',
    [string]$VhdxPath   = 'D:\WSL\Ubuntu-Dev\ext4.vhdx',
    [string]$OutRoot    = 'K:\WSL\Snapshots',
    [switch]$Terminate,
    [switch]$ExportTar,
    [switch]$CompressTar,
    [int]$Retain = 10,
    [switch]$Quiet
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Log($m){ if(-not $Quiet){ Write-Host $m } }

if (-not (Test-Path -LiteralPath $VhdxPath)) { throw "VHDX not found at $VhdxPath" }
if (-not (Test-Path -LiteralPath $OutRoot)) { New-Item -ItemType Directory -Path $OutRoot -Force | Out-Null }

$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$snapDir = Join-Path $OutRoot $stamp
New-Item -ItemType Directory -Path $snapDir -Force | Out-Null

if ($Terminate) {
    Log "Terminating distro $DistroName for clean snapshot..."
    try { wsl --terminate $DistroName | Out-Null } catch { Write-Warning "Terminate failed (may already be stopped): $($_.Exception.Message)" }
}

# Copy VHDX (preserve sparse attributes where possible)
$vhdxDest = Join-Path $snapDir "ext4_$stamp.vhdx"
Log "Copying VHDX -> $vhdxDest"
Copy-Item -LiteralPath $VhdxPath -Destination $vhdxDest -Force

if ($ExportTar) {
    $tarPath = Join-Path $snapDir ("${DistroName}_$stamp.tar")
    Log "Exporting distro to $tarPath (this may take a while)"
    wsl --export $DistroName $tarPath
    if ($CompressTar) {
        $gzPath = "$tarPath.gz"
        try {
            Log "Compressing export -> $gzPath"
            if (Get-Command gzip -ErrorAction SilentlyContinue) {
                gzip -f $tarPath
            } else {
                # Fallback: use WSL gzip (maps Windows path to /mnt/<drive>/...)
                $wslPath = $tarPath -replace '^([A-Za-z]):','/mnt/$1' -replace '\\','/'
                wsl -d $DistroName -- sh -lc "gzip -f $wslPath" 2>$null | Out-Null
            }
            if (-not (Test-Path -LiteralPath $gzPath)) { throw "Compression did not produce $gzPath" }
            Remove-Item -LiteralPath $tarPath -Force
        } catch { Write-Warning "Compression failed: $($_.Exception.Message)" }
    }
}

# Retention
if ($Retain -gt 0) {
    $existing = Get-ChildItem -Directory -Path $OutRoot | Sort-Object Name -Descending
    $toRemove = $existing | Select-Object -Skip $Retain
    foreach ($r in $toRemove) {
        try { Log "Pruning old snapshot: $($r.FullName)"; Remove-Item -Recurse -Force -LiteralPath $r.FullName } catch { Write-Warning "Failed to prune $($r.FullName): $($_.Exception.Message)" }
    }
}

Log "Snapshot complete: $snapDir"
