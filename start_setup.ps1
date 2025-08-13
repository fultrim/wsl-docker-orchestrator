# start_setup.ps1 — robust launcher with atomic report writes (no file locks)
param(
    [string]$Start,
    [switch]$AutoAll
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Resolve roots
$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$PhasesDir  = Join-Path $ScriptRoot 'phases'
$ValDir     = Join-Path $ScriptRoot 'validations'
$ReportsDir = Join-Path $ScriptRoot 'reports'
$StateDir   = Join-Path $ScriptRoot 'state'

# Ensure dirs
foreach ($p in @($PhasesDir,$ValDir,$ReportsDir,$StateDir)) {
    if (-not (Test-Path -LiteralPath $p)) { New-Item -ItemType Directory -Path $p | Out-Null }
}
$StatePath = Join-Path $StateDir 'context_state.json'
if (-not (Get-Variable -Name ContextState -Scope Global -ErrorAction SilentlyContinue)) { $Global:ContextState = $null }
if (Test-Path -LiteralPath $StatePath) {
    try { $Global:ContextState = Get-Content -Raw -LiteralPath $StatePath | ConvertFrom-Json -ErrorAction Stop } catch { $Global:ContextState = $null }
}
if (-not $Global:ContextState) {
    $Global:ContextState = [ordered]@{
        schemaVersion = 1
        created       = (Get-Date).ToString('s')
        lastUpdated   = (Get-Date).ToString('s')
        phases        = @{}
        distro        = @{}
        docker        = @{}
    health        = @{}
    }
}

function Update-ContextStatePhase([int]$id,[string]$name,[string]$status) {
    if (-not ($Global:ContextState.phases -is [System.Collections.IDictionary])) {
        $converted = [ordered]@{}
        ($Global:ContextState.phases | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name) | ForEach-Object {
            $converted[$_] = $Global:ContextState.phases."$_"
        }
        $Global:ContextState.phases = $converted
    }
    $Global:ContextState.phases["$id"] = [ordered]@{ name=$name; status=$status; timestamp=(Get-Date).ToString('s') }
    $Global:ContextState.lastUpdated = (Get-Date).ToString('s')
    Persist-ContextState
}

function Refresh-ContextDistroDocker {
    $distroName='Ubuntu-Dev'
    try {
        $osr = wsl -d $distroName -- bash -c "grep '^VERSION_ID=' /etc/os-release || true" 2>$null
        $ver = ($osr -split '=')[-1].Trim('"')
        $uname = wsl -d $distroName -- uname -r 2>$null
        $Global:ContextState.distro = [ordered]@{ name=$distroName; version=$ver; kernel=$uname }
    } catch {}
    try {
        $dockerv = wsl -d $distroName -- docker info --format '{{json .ServerVersion}}' 2>$null
        if ($dockerv) { $dockerv = $dockerv.Trim('"') }
        $images = wsl -d $distroName -- docker images --format '{{.Repository}}:{{.Tag}}' 2>$null | Select-Object -First 15
        $Global:ContextState.docker = [ordered]@{ serverVersion=$dockerv; sampleImages=$images }
    } catch {}
    $Global:ContextState.lastUpdated = (Get-Date).ToString('s')
    Persist-ContextState
}

function Persist-ContextState {
    try {
        $tmp = "$StatePath.tmp"; $json = ($Global:ContextState | ConvertTo-Json -Depth 6)
        Set-Content -LiteralPath $tmp -Value $json -Encoding UTF8
        Move-Item -Force -LiteralPath $tmp -Destination $StatePath
    } catch { Write-Warning "Failed to persist context state: $($_.Exception.Message)" }
}

function Update-HealthMetrics {
    try {
        $drives = 'D','K','P' | ForEach-Object {
            $drv = Get-PSDrive -Name $_ -ErrorAction SilentlyContinue
            if ($drv) {
                $free = [int64]$drv.Free
                $total = 0; $used = 0
                if ($drv.PSObject.Properties.Match('Used').Count -gt 0 -and $drv.PSObject.Properties.Match('Maximum').Count -gt 0) {
                    $used = [int64]$drv.Used; $total = [int64]$drv.Maximum
                } else {
                    try {
                        $vol = Get-CimInstance -ClassName Win32_LogicalDisk -Filter ("DeviceID='" + $_ + ":'")
                        if ($vol) { $total = [int64]$vol.Size; $free = [int64]$vol.FreeSpace; $used = $total - $free }
                    } catch {}
                }
                [ordered]@{ name=$_; freeBytes=$free; usedBytes=$used; totalBytes=$total }
            }
        } | Where-Object { $_ }
        $wsldir = 'D:\WSL\Ubuntu-Dev'
        $vhd = Join-Path $wsldir 'ext4.vhdx'
        $vhdSize = if (Test-Path $vhd) { (Get-Item $vhd).Length } else { 0 }
        $modelsRoot = 'K:\Models'
        $modelsSize = 0
        if (Test-Path $modelsRoot) {
            try { $modelsSize = (Get-ChildItem $modelsRoot -Recurse -ErrorAction SilentlyContinue | Where-Object { -not $_.PSIsContainer } | Measure-Object -Sum Length).Sum } catch {}
        }
        $dockerDf = $null
        try { $dockerDf = wsl -d Ubuntu-Dev -- docker system df --format '{{json .}}' 2>$null } catch {}
        if (-not ($Global:ContextState.PSObject.Properties.Name -contains 'health')) {
            # Add missing property if object got deserialized as PSCustomObject
            try { $Global:ContextState | Add-Member -NotePropertyName health -NotePropertyValue $null -Force } catch {}
        }
        $healthBlock = [ordered]@{
            timestamp   = (Get-Date).ToString('s')
            drives      = $drives
            vhdxBytes   = $vhdSize
            modelsBytes = $modelsSize
            dockerDfRaw = $dockerDf
        }
        if ($Global:ContextState -is [hashtable]) { $Global:ContextState['health']=$healthBlock } else { $Global:ContextState.health = $healthBlock }

    # Threshold evaluation
        $thresholdFile = Join-Path $ScriptRoot 'config/thresholds.json'
        if (Test-Path $thresholdFile) {
            try {
                $thr = Get-Content -Raw -LiteralPath $thresholdFile | ConvertFrom-Json
                $alerts = @()
                if ($healthBlock.drives) {
                    foreach ($d in $healthBlock.drives) {
                        if ($d.totalBytes -gt 0) {
                            $freePct = ($d.freeBytes*100.0)/$d.totalBytes
                            if ($thr.minDriveFreePct -and $freePct -lt $thr.minDriveFreePct) { $alerts += "Low free space on drive $($d.name): {0:N1}%" -f $freePct }
                        }
                    }
                }
                $vhdxGB = [math]::Round($healthBlock.vhdxBytes/1GB,2)
                if ($thr.maxVhdxGB -and $vhdxGB -gt $thr.maxVhdxGB) { $alerts += "VHDX size high: $vhdxGB GB" }
                $modelsGB = [math]::Round($healthBlock.modelsBytes/1GB,2)
                if ($thr.warnModelsGB -and $modelsGB -gt $thr.warnModelsGB) { $alerts += "Models size high: $modelsGB GB" }
                if ($alerts.Count -gt 0) {
                    $Global:ContextState.health.alerts = $alerts
                    $alertsLog = Join-Path $StateDir 'alerts.log'
                    $ts = Get-Date -Format 's'
                    foreach ($a in $alerts) { Add-Content -LiteralPath $alertsLog -Value "[$ts] $a" -Encoding UTF8 }
                }
            } catch { Write-Warning "Threshold evaluation failed: $($_.Exception.Message)" }
        }
        $Global:ContextState.lastUpdated = (Get-Date).ToString('s')
        Persist-ContextState

        # Append metrics line (timestamp,vhdxGB,modelsGB,<driveFreePct...>,dockerImagesCount)
        try {
            $metricsFile = Join-Path $StateDir 'metrics_history.csv'
            $ts = Get-Date -Format 's'
            $vhdxGB = [math]::Round($healthBlock.vhdxBytes/1GB,2)
            $modelsGB = [math]::Round($healthBlock.modelsBytes/1GB,2)
            $drivePcts = @()
            foreach ($d in $healthBlock.drives) { if ($d.totalBytes -gt 0) { $drivePcts += [math]::Round(($d.freeBytes*100.0)/$d.totalBytes,2) } else { $drivePcts += '' } }
            $dockerImagesCount = 0
            try { $dockerImagesCount = (wsl -d Ubuntu-Dev -- docker images -q 2>$null | Measure-Object).Count } catch {}
            $line = ($ts, $vhdxGB, $modelsGB) + $drivePcts + $dockerImagesCount -join ','
            if (-not (Test-Path $metricsFile)) {
                $driveHeaders = ($healthBlock.drives | ForEach-Object { "drive_$($_.name)_freePct" }) -join ','
                $header = 'timestamp,vhdxGB,modelsGB,' + $driveHeaders + ',dockerImagesCount'
                Set-Content -LiteralPath $metricsFile -Value $header -Encoding UTF8
            }
            Add-Content -LiteralPath $metricsFile -Value $line -Encoding UTF8
        } catch { Write-Warning "Metrics append failed: $($_.Exception.Message)" }
    } catch { Write-Warning "Health metrics update failed: $($_.Exception.Message)" }
}

# Phase table
$Phases = @(
    [pscustomobject]@{ Id=1; Name='Directory Preparation';                   Script=(Join-Path $PhasesDir 'phase1_setup_dirs.ps1');          Validate=(Join-Path $ValDir 'validate_phase1.ps1');          Report=(Join-Path $ReportsDir 'phase1_report.txt') },
    [pscustomobject]@{ Id=2; Name='Baseline Import (WSL Ubuntu-Dev)';        Script=(Join-Path $PhasesDir 'phase2_import_wsl.ps1');          Validate=(Join-Path $ValDir 'validate_phase2.ps1');          Report=(Join-Path $ReportsDir 'phase2_report.txt') },
    [pscustomobject]@{ Id=3; Name='WSL Config & Docker Engine Install';      Script=(Join-Path $PhasesDir 'phase3_configure_wsl_docker.ps1');Validate=(Join-Path $ValDir 'validate_phase3.ps1');          Report=(Join-Path $ReportsDir 'phase3_report.txt') },
    [pscustomobject]@{ Id=4; Name='Model Path Junction Setup';               Script=(Join-Path $PhasesDir 'phase4_models_setup.ps1');        Validate=(Join-Path $ValDir 'validate_phase4.ps1');          Report=(Join-Path $ReportsDir 'phase4_report.txt') }
)

function Section([string]$Text) {
    Write-Host ""
    Write-Host "=== $Text ===" -ForegroundColor Cyan
}

function Invoke-Phase([pscustomobject]$Phase) {
    if (-not (Test-Path -LiteralPath $Phase.Script)) {
        throw ("Phase {0} script not found: {1}" -f $Phase.Id, $Phase.Script)
    }
    $runLog  = Join-Path $ReportsDir ("phase{0}_run.log" -f $Phase.Id)
    $runTmp  = Join-Path $ReportsDir ("phase{0}_run_{1}.tmp" -f $Phase.Id, (Get-Date -Format 'yyyyMMdd_HHmmssfff'))

    Write-Host ("Running Phase {0}: {1}" -f $Phase.Id, $Phase.Name) -ForegroundColor Yellow
    Write-Host ("Script: {0}" -f $Phase.Script) -ForegroundColor DarkGray

    try {
        $out = & $Phase.Script *>&1 | Out-String
        $hdr = "=== Phase {0} Run Output ===`r`n{1}`r`n" -f $Phase.Id, (Get-Date -Format s)
        Set-Content -LiteralPath $runTmp -Value ($hdr + $out) -Encoding UTF8
        Move-Item -Force -LiteralPath $runTmp -Destination $runLog
    }
    catch {
        $err = ("`r`n[ERROR] {0}`r`n{1}" -f (Get-Date -Format s), ($_ | Out-String))
        Add-Content -LiteralPath $runTmp -Value $err -Encoding UTF8
        Move-Item -Force -LiteralPath $runTmp -Destination $runLog
        throw ("Phase {0} failed. See log: {1}" -f $Phase.Id, $runLog)
    }
}

function Invoke-Validation([pscustomobject]$Phase) {
    if (-not (Test-Path -LiteralPath $Phase.Validate)) { throw ("ERROR: Validation script missing for phase {0}." -f $Phase.Id) }
    $report=$Phase.Report; $tmp=Join-Path $ReportsDir ("phase{0}_report_{1}.tmp" -f $Phase.Id,(Get-Date -Format 'yyyyMMdd_HHmmssfff'))
    Write-Host ("Validating Phase {0}: {1}" -f $Phase.Id,$Phase.Name) -ForegroundColor Green
    $out=''; $code=1
    try { $out = & $Phase.Validate *>&1 | Out-String; $code=$LASTEXITCODE } catch { $out += "`nEXCEPTION: " + ($_ | Out-String); $code=1 }
    $hdr = "=== Phase {0} Validation Report ===`r`n{1}`r`n" -f $Phase.Id,(Get-Date -Format s)
    Set-Content -LiteralPath $tmp -Value ($hdr+$out) -Encoding UTF8; Move-Item -Force -LiteralPath $tmp -Destination $report
    if ($out -match 'RESULT:\s*FAIL' -or $code -ne 0) { throw ("ERROR: Validation failed for phase {0}. See report: {1}" -f $Phase.Id,$report) }
    Write-Host ("Phase {0} validation passed. Report: {1}" -f $Phase.Id,$report) -ForegroundColor Green
}

Section "WSL / Docker Setup Launcher"
Write-Host "Available phases:" -ForegroundColor Cyan
$Phases | ForEach-Object { Write-Host ("  {0}. {1}" -f $_.Id, $_.Name) }

function Resolve-StartChoice {
    if ($AutoAll) { return 'all' }
    if ($Start) { return $Start }
    if ($env:CI -eq 'true' -or $env:GITHUB_ACTIONS -eq 'true' -or $env:ORCH_AUTO_ALL -eq '1') { return 'all' }
    return $null
}
$choice = Resolve-StartChoice
if (-not $choice) { $choice = Read-Host 'Enter starting phase number (1-4) or "all"' }
if ($choice -match '^(all)$') { $startId = 1 }
elseif ($choice -match '^[1-4]$') { $startId = [int]$choice }
else { Write-Error ("Invalid selection: {0}" -f $choice); exit 1 }

$runList = $Phases | Where-Object { $_.Id -ge $startId } | Sort-Object Id
Section ("Starting at phase {0}" -f $startId)

$transcript = Join-Path $ReportsDir ("launcher_{0}.log" -f (Get-Date -Format 'yyyyMMdd_HHmmss'))
Start-Transcript -Path $transcript -Force | Out-Null

try {
    foreach ($p in $runList) {
        Section ("Phase {0}: {1}" -f $p.Id, $p.Name)
    Invoke-Phase      -Phase $p
    Invoke-Validation -Phase $p
    Update-ContextStatePhase -id $p.Id -name $p.Name -status 'PASS'
    if ($p.Id -eq 2 -or $p.Id -eq 3) { Refresh-ContextDistroDocker }
    Update-HealthMetrics
    }
    Section "All requested phases completed successfully."
    Write-Host ("Transcript: {0}" -f $transcript) -ForegroundColor DarkGray
    exit 0
}
catch { Write-Host ""; $m=$_.Exception.Message; if ($m -notmatch '^ERROR:'){ $m='ERROR: '+$m }; Write-Host $m -ForegroundColor Red; Write-Host ("See logs in: {0}" -f $ReportsDir) -ForegroundColor Yellow; Write-Host ("Transcript: {0}" -f $transcript) -ForegroundColor DarkGray; exit 2 }
finally {
    Stop-Transcript | Out-Null
}
