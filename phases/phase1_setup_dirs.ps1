<#
Phase 1 — Directory Preparation
Creates required directories on D, K, P. Idempotent.
Outputs required success line.
#>
try {
    $paths = @(
        'D:\\Docker',
        'D:\\WSL',
        'D:\\ModelsCurrent',
        'K:\\Baselines\\WSL',
        'K:\\Baselines\\Docker',
        'K:\\Models',
        'K:\\Archive',
        'P:\\Models',
        'P:\\wsl2-swap'
    )
    foreach ($p in $paths) { if (-not (Test-Path -LiteralPath $p)) { New-Item -ItemType Directory -Path $p -Force | Out-Null } }
    Write-Output 'Phase 1 completed: Directory structure created.'
}
catch { Write-Error "Phase 1 error: $($_.Exception.Message)"; exit 1 }
