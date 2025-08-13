param(
  [Parameter(Mandatory=$true, Position=0)][ValidateSet('List','Move','Shrink','Export','Import','Clone')]$Command,
  [string]$Name,
  [string]$To,
  [string]$Out,
  [string]$From,
  [string]$NewName,
  [string]$NewPath
)
<#
WSL Management Utility
Commands:
  List                                 - Show all distros, version, state, heuristic VHDX path & size
  Move     -Name <Distro> -To <D:\TargetPath>
  Shrink   -Name <Distro>
  Export   -Name <Distro> -Out K:\Baselines\WSL\file.tar
  Import   -Name <Distro> -From <tar> -To <InstallDir>
  Clone    -Name <Distro> -NewName <CloneName> -NewPath <D:\TargetPath>  (export+import without removing source)
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
  'Clone' {
    if (-not $Name -or -not $NewName -or -not $NewPath) { throw 'Clone requires -Name -NewName -NewPath' }
    if (-not (wsl --list --quiet | Where-Object { $_ -eq $Name })) { throw "Source distro $Name not found" }
    if ((wsl --list --quiet) -contains $NewName) { throw "Target distro $NewName already exists" }
    if (-not (Test-Path -LiteralPath $NewPath)) { New-Item -ItemType Directory -Path $NewPath -Force | Out-Null }
    $tmp = Join-Path $env:TEMP ("wslclone_{0}_to_{1}_{2}.tar" -f $Name,$NewName,(Get-Date -Format 'yyyyMMdd_HHmmss'))
    Write-Output ("Exporting {0} -> {1}" -f $Name,$tmp)
    wsl --export $Name $tmp
    Write-Output ("Importing clone {0} -> {1}" -f $NewName,$NewPath)
    wsl --import $NewName $NewPath $tmp --version 2
    Remove-Item $tmp -Force
    Write-Output ("Clone complete: {0} -> {1}" -f $Name,$NewName)
  }
}
