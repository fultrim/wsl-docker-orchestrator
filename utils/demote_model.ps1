param(
    [Parameter(Mandatory=$true)][string]$Name
)
<#
Utility: Demote model
 - Mirrors P:\Models\<Name> back to K:\Models\<Name>
 - Points D:\ModelsCurrent junction to K:\Models
 - Does not delete P copy.
Outputs: Demoted <Name> to K:\Models and updated D:\ModelsCurrent.
#>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$p = Join-Path 'P:\Models' $Name
$k = Join-Path 'K:\Models' $Name
if (-not (Test-Path -LiteralPath $p)) { Write-Error "Promoted model missing: $p"; exit 1 }
if (-not (Test-Path -LiteralPath $k)) { New-Item -ItemType Directory -Path $k -Force | Out-Null }
robocopy $p $k /MIR /NFL /NDL /NP /R:1 /W:1 | Out-Null
if (Test-Path 'D:\ModelsCurrent') { Remove-Item 'D:\ModelsCurrent' -Force }
cmd /c mklink /D "D:\ModelsCurrent" "K:\Models" | Out-Null
Write-Output ("Demoted {0} to K:\Models and updated D:\ModelsCurrent." -f $Name)
