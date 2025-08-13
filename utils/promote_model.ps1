param(
    [Parameter(Mandatory=$true)][string]$Name
)
<#
Utility: Promote model
 - Mirrors K:\Models\<Name> to P:\Models\<Name> using robocopy /MIR
 - Points D:\ModelsCurrent junction to P:\Models
 - Idempotent
Outputs: Promoted <Name> to P:\Models and updated D:\ModelsCurrent.
#>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$src = Join-Path 'K:\Models' $Name
$dst = Join-Path 'P:\Models' $Name
if (-not (Test-Path -LiteralPath $src)) { Write-Error "Source model missing: $src"; exit 1 }
if (-not (Test-Path -LiteralPath (Split-Path $dst))) { New-Item -ItemType Directory -Path (Split-Path $dst) -Force | Out-Null }
robocopy $src $dst /MIR /NFL /NDL /NP /R:1 /W:1 | Out-Null
if (Test-Path 'D:\ModelsCurrent') { Remove-Item 'D:\ModelsCurrent' -Force }
cmd /c mklink /D "D:\ModelsCurrent" "P:\Models" | Out-Null
Write-Output ("Promoted {0} to P:\Models and updated D:\ModelsCurrent." -f $Name)
