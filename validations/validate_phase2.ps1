<# Validation Phase 2 — check distro, vhdx, and Jammy markers. #>
$errors = @(); $name='Ubuntu-Dev'; $ext4='D:\\WSL\\Ubuntu-Dev\\ext4.vhdx'
$list = wsl --list --quiet 2>$null
if ($list -notcontains $name) { $errors += 'Distro not registered' }
if (-not (Test-Path -LiteralPath $ext4)) { $errors += 'Missing VHDX' }
if ($list -contains $name) {
	$osr = wsl.exe -d $name -- sh -lc 'cat /etc/os-release' 2>$null
	$text = ($osr | Out-String)
	if ($text -notmatch '22\.04' -or $text -notmatch 'jammy') { $errors += 'Not Jammy 22.04' }
}
if ($errors.Count -eq 0){ Write-Output 'Ubuntu-Dev present with Jammy baseline.'; Write-Output 'RESULT: PASS'; exit 0 }
Write-Output ('Errors: ' + ($errors -join '; ')); Write-Output 'RESULT: FAIL'; exit 1
