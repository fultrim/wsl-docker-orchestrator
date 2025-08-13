<# Validation Phase 3 — systemd enabled & native docker engine responsive. #>
$distro='Ubuntu-Dev'; $errors=@();
$conf=wsl -d $distro -- bash -c "grep -i '^systemd=true' /etc/wsl.conf 2>/dev/null || true"
if (-not $conf){$errors+='systemd=true missing'}
$whichDocker = wsl -d $distro -- bash -c 'command -v docker || true'
if (-not $whichDocker){ $errors+='docker binary missing' }
else {
		$info = wsl -d $distro -- bash -c 'docker info --format {{.ServerVersion}} 2>/dev/null || sudo docker info --format {{.ServerVersion}} 2>/dev/null || true'
		if (-not $info){ $errors+='docker info failed' }
	elseif ($info -match "could not be found" ){ $errors+='docker placeholder shim (Desktop) present' }
	# buildx and compose plugin checks (non-fatal warnings)
	$bx = wsl -d $distro -- bash -c 'docker buildx version 2>/dev/null || true'
	if (-not $bx){ $errors+='docker buildx missing' }
	$compose = wsl -d $distro -- bash -c 'docker compose version 2>/dev/null || true'
	if (-not $compose){ $errors+='docker compose plugin missing' }
}
if ($errors.Count -eq 0){ Write-Output 'Docker Engine responsive.'; Write-Output 'RESULT: PASS'; exit 0 }
Write-Output ('Issues: ' + ($errors -join '; ')); Write-Output 'RESULT: FAIL'; exit 1
