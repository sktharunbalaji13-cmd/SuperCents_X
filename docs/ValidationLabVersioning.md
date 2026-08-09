# Validation Lab — Versioning Policy

## API Compatibility Rules

The Validation Lab public API (defined in `APIReference_v2.7.md`) follows semantic versioning with the following specific rules.

### Compatible Changes (minor/patch)

- **Appending fields to a struct** — New fields must have default constructors that produce safe (zero-equivalent) values.
- **Appending values to an enum** — New values must be appended after existing values. Their numeric order must not reorder existing entries.
- **Adding new functions** — New public methods on existing classes may be added if they do not conflict with existing method signatures.
- **Adding new modules** — New validation phases, data sources, or event handlers should follow the extension patterns in `ARCHITECTURE_v2.7.md`.

### Breaking Changes (major)

- **Renaming public fields** — Any field name change in a frozen struct.
- **Changing semantic meaning** — Keeping the same field name but changing what it represents.
- **Removing public fields** — Deleting a field from a frozen struct.
- **Removing enum values** — Deleting or reordering values in a frozen enum.
- **Changing method signatures** — Adding required parameters, removing parameters, or changing parameter types in existing public methods.
- **Changing class inheritance** — Modifying the base class of a public class.
- **Removing public classes or methods** — Deleting any documented class or method.

## Semantic Versioning Policy

| Component | Version Scheme | Notes |
|-----------|---------------|-------|
| Validation Lab subsystem | `major.minor.patch` | Tracks the EA version (currently 2.7.x) |
| Public API (frozen types) | `major` only | API version increments when a breaking change is accepted |
| Benchmark baseline | `major.minor` | Baseline file name embeds the EA version |

## What Constitutes a Breaking Change

A change is breaking if it would cause code that compiles and runs against v2.7 to either:

1. Fail to compile against the new version, or
2. Compile but produce different runtime behavior for the same inputs without notice.

Examples:

| Change | Severity | Rationale |
|--------|----------|-----------|
| Add field with default constructor to struct | Compatible | All existing code still compiles and reads safe defaults |
| Add new enum value | Compatible | Existing `switch` statements without `default` will generate compiler warnings, but old code remains valid |
| Rename `validWindows` → `successfulWindows` | Breaking | All code referencing `validWindows` must change |
| Change `probabilityOfLoss` from `double` to `float` | Breaking | ABI change; precision loss |
| Reorder `ENUM_WALK_FORWARD_MODE` values | Breaking | Serialized data becomes misaligned |

## Deprecation Policy

1. Mark deprecated fields with a `// @deprecated since x.y` comment in the source header.
2. Deprecated fields remain in the struct for at least one major version cycle.
3. After one major cycle, deprecated fields may be removed in a new major version.
4. Deprecation should be announced in release notes.

## How Future Validation Modules Should Evolve

### Adding a New Validation Phase

1. Create typed structs in a new `*Types.mqh` file under `Validation/`.
2. Create a pipeline class with an `Execute(...)` method that returns the typed summary.
3. Add `has*` / `summary*` pair to `ValidationReport` in `ReportTypes.mqh`.
4. Add composition to `CValidationReportComposer`.
5. Add freeze annotation and API reference entry.
6. Add test coverage to `TestRunner.mq5`.
7. Add benchmark coverage to `BenchmarkRunner.mq5`.

### Adding a New Data Source

1. Implement `IValidationDataSource`.
2. Register via `CValidationLab::SetDataSource()`.
3. Ensure `Prepare()`, `Finalize()`, and `Shutdown()` lifecycle methods are correct.

### Adding a New Monte Carlo Perturbation Mode

1. Append value to `ENUM_PERTURBATION_MODE`.
2. Implement the perturbation logic in `CMonte CarloSimulator`.
3. Add validation in the pipeline config.

### Adding a New Regression Dimension

1. Append value to `ENUM_REGRESSION_DIMENSION`.
2. Extract the metric from `StrategyReport` in `CRegressionDetector`.
3. Add a sensible default threshold.

## Version History

| API Version | EA Version | Date | Notes |
|-------------|------------|------|-------|
| 1 | 2.7 | 2026-07-30 | Initial frozen API |

---

*This document should be updated when the API version changes. Keep the version history table current.*
