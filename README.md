# SuperCents_X

MetaTrader 5 Expert Advisor project - entry point `SuperCents_X.mq5`, plus the
standalone `CalibrationRunner.mq5` calibration tool.

## Repository layout (EA-rooted)

- `Core/`, `Structure/` - domain core and system structure
- `Entry/`, `Trading/`, `Risk/`, `Monitoring/`, `Production/` - trading pipeline
- `Validation/` - validation framework (`ValidationLab`, Monte Carlo,
  Walk-Forward, regression detection); Sprint-17 collection evidence in
  `Validation/Sprint17/`
- `Visualization/`, `Calibration/`, `Optimization/`, `Portfolio/`,
  `Presets/`, `Research/`, `Knowledge/`, `Laboratory/`, `Confluence/`
- `docs/` - protocol and analysis documents (Sprint20_ED01D_Protocol, RH01)
- `Tests/` - unit tests (MQ5 test runners); `Tools/`, `Utils/`, `Providers/`
- `benchmarks/`, `Telemetry/`, `Regression/`, `RegressionLogs/`
- `CHANGELOG.md`, `SuperCents_X.mq5`, `CalibrationRunner.mq5`

## Workspace-only material (gitignored, not part of the canonical repo)

MQL5 workspace artifacts (`Evidence/`, `Files/`, `Scripts/`, `Tests/CI/`,
`Experts/`) remain on disk outside the canonical tree by design.

## Build

Compile `SuperCents_X.mq5` and `CalibrationRunner.mq5` in MetaEditor.
Test runners live under `Tests/` and are compiled alongside the EA.
