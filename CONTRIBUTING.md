# Contributing

## Development Flow
1. Run `./start_setup.ps1 -AutoAll` to ensure environment prepared.
2. Modify phase or validation scripts; keep idempotent.
3. Run `./tests/run_all_validations.ps1` before commit.
4. Update metrics logic if adding health data columns.
5. Open a PR; CI, Nightly, Alerts & Metrics workflows will run.

## Guidelines
* Use strict mode.
* Atomic writes for reports/state.
* Avoid altering existing metrics column order.

## Adding Tests
Place new scripts in `tests/test_*.ps1`; they run automatically.

## Security
No secrets in repo. Use GitHub secrets if ever required.
