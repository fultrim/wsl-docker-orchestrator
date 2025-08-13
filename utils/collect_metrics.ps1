<#!
Reads metrics_history.csv and outputs latest snapshot and simple averages.
!#>
param([switch]$Json)
$stateDir = Join-Path (Split-Path $MyInvocation.MyCommand.Path -Parent) 'state'
$metrics = Join-Path $stateDir 'metrics_history.csv'
if (-not (Test-Path $metrics)) { Write-Error 'metrics_history.csv not found'; exit 1 }
$rows = Get-Content -LiteralPath $metrics
if ($rows.Count -lt 2) { Write-Error 'No data rows yet'; exit 2 }
$header = ($rows[0].Split(',')).Trim()
$data = $rows[1..($rows.Count-1)] | ForEach-Object {
  $vals = $_.Split(',')
  $obj = [ordered]@{}
  for($i=0;$i -lt $header.Length;$i++){ $obj[$header[$i]] = $vals[$i] }
  [pscustomobject]$obj
}
$latest = $data[-1]
if ($Json) { $latest | ConvertTo-Json -Depth 3; exit 0 }
Write-Host '=== Latest Metrics ==='
$latest.PSObject.Properties | ForEach-Object { Write-Host ("{0} = {1}" -f $_.Name,$_.Value) }
Write-Host '=== Averages (numeric columns) ==='
$numProps = $header | Where-Object { $_ -ne 'timestamp' }
foreach($p in $numProps){
  $vals = @()
  foreach($row in $data){ if ($row.$p -match '^[0-9.]+$'){ $vals += [double]$row.$p } }
  if ($vals.Count -gt 0){ $avg = ($vals | Measure-Object -Average).Average; Write-Host ("{0} avg = {1:N2}" -f $p,$avg) }
}
