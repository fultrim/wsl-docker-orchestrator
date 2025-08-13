param([Parameter(Mandatory=$true)][string]$Name)
<# Demote model and repoint junction back to K. #>
$p=Join-Path 'P:\\Models' $Name; $k=Join-Path 'K:\\Models' $Name
if (-not (Test-Path -LiteralPath $p)) { Write-Error "Promoted model missing: $p"; exit 1 }
robocopy $p $k /MIR /NFL /NDL /NP /R:1 /W:1 | Out-Null
if (Test-Path 'D:\\ModelsCurrent'){ Remove-Item 'D:\\ModelsCurrent' -Force }
cmd /c mklink /D "D:\\ModelsCurrent" "K:\\Models" | Out-Null
Write-Output ("Demoted {0} to K:\\Models and updated D:\\ModelsCurrent." -f $Name)
