param([Parameter(Mandatory=$true)][string]$Name)
<# Promote model and repoint junction. #>
$src=Join-Path 'K:\\Models' $Name; $dst=Join-Path 'P:\\Models' $Name
if (-not (Test-Path -LiteralPath $src)) { Write-Error "Model missing: $src"; exit 1 }
robocopy $src $dst /MIR /NFL /NDL /NP /R:1 /W:1 | Out-Null
if (Test-Path 'D:\\ModelsCurrent'){ Remove-Item 'D:\\ModelsCurrent' -Force }
cmd /c mklink /D "D:\\ModelsCurrent" "P:\\Models" | Out-Null
Write-Output ("Promoted {0} to P:\\Models and updated D:\\ModelsCurrent." -f $Name)
