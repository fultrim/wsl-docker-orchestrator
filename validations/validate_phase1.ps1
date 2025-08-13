<#
Validation Phase 1 — ensure all required dirs exist and emit RESULT line.
#>
$required = @(
    'D:\\Docker',
    'D:\\WSL',
    'D:\\ModelsCurrent',
    'K:\\Baselines\\WSL',
    'K:\\Baselines\\Docker',
    'K:\\Models',
    'K:\\Archive',
    'P:\\Models'
)
$missing = @()
foreach ($r in $required) { if (-not (Test-Path -LiteralPath $r)) { $missing += $r } }
if ($missing.Count -eq 0) { Write-Output 'All required directories present.'; Write-Output 'RESULT: PASS'; exit 0 }
Write-Output ('Missing: ' + ($missing -join ', '))
Write-Output 'RESULT: FAIL'
exit 1
