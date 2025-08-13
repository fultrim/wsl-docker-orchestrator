<# Validation Phase 4 — junction correctness (simplified). #>
$junction='D:\\ModelsCurrent'; $target='K:\\Models'; $errors=@();
if (-not (Test-Path -LiteralPath $junction)) { $errors += 'Missing junction' }
else {
	$fsutil = (cmd /c "fsutil reparsepoint query $junction" 2>&1 | Out-String)
	if ($fsutil -notmatch 'Mount Point') { $errors += 'Not a junction' }
	if ($fsutil -notmatch 'Print Name:') { $errors += 'Missing print name' }
	if ($fsutil -notmatch 'K:\\Models') { $errors += 'Wrong target' }
}
if ($errors.Count -eq 0) { Write-Output 'Models junction correct.'; Write-Output 'RESULT: PASS'; exit 0 }
Write-Output ('Issues: ' + ($errors -join '; ')); Write-Output 'RESULT: FAIL'; exit 1
