<# Phase 4 — Ensure D:\ModelsCurrent junction -> K:\Models (idempotent). #>
try {
    $junction='D:\\ModelsCurrent'; $target='K:\\Models'
    if (-not (Test-Path -LiteralPath $target)) { New-Item -ItemType Directory -Path $target -Force | Out-Null }
    $needs=$true
    if (Test-Path -LiteralPath $junction) {
        $rp = (cmd /c dir $junction 2>nul | Out-String)
        if ($rp -match 'JUNCTION' -and $rp -match [regex]::Escape($target)) { $needs=$false } else { Remove-Item -LiteralPath $junction -Force -Recurse }
    }
    if ($needs){ cmd /c mklink /J "$junction" "$target" | Out-Null }
    Write-Output 'Phase 4 completed: Models junction set to K:\\Models.'
}
catch { Write-Error "Phase 4 error: $($_.Exception.Message)"; exit 1 }
