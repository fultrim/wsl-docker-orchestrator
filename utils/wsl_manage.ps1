param(
    [Parameter(Mandatory=$true, Position=0)][ValidateSet('List','Move','Shrink','Export','Import')]$Command,
    [string]$Name,
    [string]$To,
    [string]$Out,
    [string]$From
)
<#
WSL Management Utility
Commands:
  List                         - Show all distros, version, state, heuristic VHDX path & size
  Move   -Name <Distro> -To <D:\TargetPath>
  Shrink -Name <Distro>
  Export -Name <Distro> -Out K:\Baselines\WSL\file.tar
  Import -Name <Distro> -From <tar> -To <InstallDir>
#>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
function Get-DistroVhdxPath($distro) {
    $candidates = @(
        Join-Path 'D:\WSL' $distro
    )
    foreach ($c in $candidates) {
        $p = Join-Path $c 'ext4.vhdx'
        if (Test-Path -LiteralPath $p) { return $p }
    }
    return $null
}

switch ($Command) {
  'List' {
    $raw = wsl --list --verbose 2>$null
    Write-Output $raw
    $names = ($raw -split "`n" | Select-Object -Skip 1 | ForEach-Object { ($_ -split '\s+')[0] } | Where-Object { $_ }) | Sort-Object -Unique
    foreach ($n in $names) {
        $vhd = Get-DistroVhdxPath $n
        if ($vhd) { $size = (Get-Item -LiteralPath $vhd).Length; Write-Output ("{0}: {1} bytes -> {2}" -f $n,$size,$vhd) } else { Write-Output ("{0}: (vhdx not found)" -f $n) }
    }
  }
  'Move' {
    if (-not $Name -or -not $To) { throw 'Move requires -Name and -To' }
    if (-not (Test-Path -LiteralPath $To)) { New-Item -ItemType Directory -Path $To -Force | Out-Null }
    $tmp = Join-Path $env:TEMP ("wslmove_{0}_{1}.tar" -f $Name,(Get-Date -Format 'yyyyMMdd_HHmmss'))
    wsl --export $Name $tmp
    wsl --unregister $Name
    wsl --import $Name $To $tmp --version 2
    Remove-Item $tmp -Force
    Write-Output ("Move complete: {0} -> {1}" -f $Name,$To)
  }
  'Shrink' {
    if (-not $Name) { throw 'Shrink requires -Name' }
    $vhd = Get-DistroVhdxPath $Name
    if (-not $vhd) { throw "Could not locate VHDX for $Name" }
    wsl --shutdown
    Optimize-VHD -Path $vhd -Mode Full
    Write-Output ("Shrink complete: {0}" -f $vhd)
  }
  'Export' {
    if (-not $Name -or -not $Out) { throw 'Export requires -Name and -Out' }
    $dir = Split-Path -Parent $Out
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    wsl --export $Name $Out
    Write-Output ("Exported {0} -> {1}" -f $Name,$Out)
  }
  'Import' {
    if (-not $Name -or -not $From -or -not $To) { throw 'Import requires -Name -From -To' }
    if ((wsl --list --quiet) -contains $Name) { throw "Distro $Name already exists." }
    if (-not (Test-Path -LiteralPath $From)) { throw "File missing: $From" }
    if (-not (Test-Path -LiteralPath $To)) { New-Item -ItemType Directory -Path $To -Force | Out-Null }
    wsl --import $Name $To $From --version 2
    Write-Output ("Imported {0} from {1} -> {2}" -f $Name,$From,$To)
  }
}
