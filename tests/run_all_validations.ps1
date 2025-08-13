<#
Test Harness: Executes all validation scripts and aggregates RESULT lines.
Intended for CI or autonomous agent verification.
#>
$ErrorActionPreference='Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$base = Split-Path $root
$valDir = Join-Path $base 'validations'
$results = @()
Get-ChildItem $valDir -Filter 'validate_phase*.ps1' | Sort-Object Name | ForEach-Object {
  Write-Host "Running $($_.Name)" -ForegroundColor Cyan
  $out = & $_.FullName 2>&1
  $line = ($out -split "`n") | Where-Object { $_ -match 'RESULT:' } | Select-Object -First 1
  $status = if ($line -match 'PASS') { 'PASS' } else { 'FAIL' }
  $results += [pscustomobject]@{Validation=$_.Name;Status=$status}
  if ($status -ne 'PASS') { Write-Host $out -ForegroundColor Red }
}
$results | Format-Table -AutoSize
if ($results.Status -contains 'FAIL') { Write-Error 'One or more validations failed.'; exit 1 }
Write-Host 'All validations PASS.' -ForegroundColor Green

# Run extended tests if present
$testDir = Join-Path $base 'tests'
$testScripts = Get-ChildItem $testDir -Filter 'test_*.ps1' -File -ErrorAction SilentlyContinue | Sort-Object Name
if ($testScripts) {
  Write-Host "\nExecuting test scripts..." -ForegroundColor Yellow
  foreach ($t in $testScripts) {
    Write-Host "Running $($t.Name)" -ForegroundColor Cyan
    & $t.FullName
    if ($LASTEXITCODE -ne 0) { Write-Error "Test failed: $($t.Name)"; exit 1 }
  }
  Write-Host 'All tests PASS.' -ForegroundColor Green
}
