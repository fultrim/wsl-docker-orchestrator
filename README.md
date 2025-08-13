# WSL / Docker Storage Orchestrator

Multi‑phase, idempotent setup for a Jammy (22.04) WSL2 dev distro with Docker Engine and deterministic storage layout across D / K / P drives.

## Drives & Roles

- C: (OS only, avoided)
- D: Active runtime (WSL VHDX, Docker layers, working data)
- K: Baselines / archives (WSL exports, model masters, Docker archives)
- P: Ultra‑fast promotion drive (Models hot path)

## Phases

1. Directory Preparation — creates required folder structure.
2. Baseline Import — registers Ubuntu-Dev (Jammy preferred) at `D:\WSL\Ubuntu-Dev`.
3. Systemd + Docker — enables systemd & installs Docker Engine in Ubuntu-Dev.
4. Models Junction — ensures `D:\ModelsCurrent` is a junction to `K:\Models`.

Each phase has a paired validation script emitting `RESULT: PASS` / `RESULT: FAIL` and proper exit codes. The launcher performs atomic log/report writes.

## Usage

Run from elevated PowerShell (5.1+):

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\start_setup.ps1
```

Choose a starting phase number or `all`. Logs and validation reports land in `reports/` plus a master launcher transcript.

## Utilities (utils/)

- `promote_model.ps1` / `demote_model.ps1` — mirror model folders between K and P then repoint `D:\ModelsCurrent`.
- `wsl_manage.ps1` — List / Move / Shrink / Export / Import WSL distros.
- `snapshot_wsl_vhdx.ps1` — Snapshot `ext4.vhdx` (and optional `wsl --export`) to `K:\WSL\Snapshots` with retention.

### Examples

```powershell
./utils/wsl_manage.ps1 List
./utils/wsl_manage.ps1 Export -Name Ubuntu-Dev -Out K:\Baselines\WSL\Ubuntu-Dev-backup.tar
./utils/wsl_manage.ps1 Shrink -Name Ubuntu-Dev
./utils/promote_model.ps1 -Name MyModel
./utils/demote_model.ps1 -Name MyModel
```

## VHDX Snapshot & Export

Use `utils/snapshot_wsl_vhdx.ps1` to capture point-in-time copies of the WSL distro disk and (optionally) a logical export.

Example:

```powershell
./utils/snapshot_wsl_vhdx.ps1 -Terminate -ExportTar -CompressTar -Retain 7
```

Outputs (under `K:\WSL\Snapshots\<timestamp>`):

- `ext4_<timestamp>.vhdx` — raw sparse disk copy
- Optional `<distro>_<timestamp>.tar.gz` — exported filesystem (portable)

Retention keeps only the N newest snapshot directories.

Tip: Schedule via Windows Task Scheduler (Daily):

Action: `powershell.exe -NoProfile -ExecutionPolicy Bypass -File D:\wsl_docker_setup\utils\snapshot_wsl_vhdx.ps1 -Terminate -Retain 14`

Ensure you do NOT commit these large artifacts (they are excluded by `.gitignore`).

## Idempotency Notes

- Re-running phases skips existing correct state (baseline re-import only if not Jammy).
- Docker install skipped if `docker info` already succeeds.
- Junction recreated only if missing or incorrect.

## Validation Summary

- Phase 2: Ubuntu-Dev registered (WSL2), ext4.vhdx exists, `/etc/os-release` contains 22.04 / jammy.
- Phase 3: `systemd=true` in `/etc/wsl.conf`, `docker info` succeeds.
- Phase 4: Junction `D:\ModelsCurrent` -> `K:\Models`.

## Troubleshooting

See `reports/phaseN_run.log` and `reports/phaseN_report.txt`. If validation fails, correct underlying issue (network, drives) then rerun starting at failed phase.

## Disclaimer

Scripts hard‑code drive letters per design. Ensure K: and P: are present before running or adapt (outside baseline acceptance criteria).
