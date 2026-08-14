# Sprint 25A — G8 Status: Runtime Identity Manifest Finalization

Authorized targeted fix (senior review): finalization/provenance reliability only.
No full TT01 rerun. No EA / telemetry / baseline / gate-semantics changes.
Scope limited to `Tools\TT01\` pipeline infrastructure.

Date: 2026-08-15 | Branch: none (working tree only, gitHead `73e5886`, no commit, no push)

---

## 1. Run-5 reference

- Run id: `TT01_20260814_235134` (launched 2026-08-14 23:51:34)
- Gate record: **17/17 PASS** in `Tools\TT01\run\gates.jsonl` (SHA256 `2E221E7FE86D75D7C296827292AB45CDA6279EE34F48E3B98462A27D93E9277F`, verified byte-identical after all G8 work)
- Artifacts: `Tools\TT01\artifacts\TT01_20260814_235134\` (binaries, telemetry CSVs, `runtime_identity.log`, `suite_journal_slice.log` 496,945 B / 3,990 lines)
- Run-5 manifest: **absent** — the run was interrupted during finalization before `manifest.json` was persisted (see Section 2)
- G7 verdict (unchanged by G8 work): **PASS** on the Run-5 17/17 record

## 2. Exact G8 mechanism — why Run-5 never wrote manifest.json

Sequence of Run-5 finalization (pre-fix harness):

1. `run/gates.jsonl` — appended per gate at decision time via `Add-TT01Result` (durable, unaffected). This is why all 17 gates survived.
2. `manifest.json` — written **last** in finalize, after evidence copies, baseline update, and binary archive, inside `Write-TT01Manifest`.
3. `Write-TT01Manifest` embedded `buildIdentity.runtime.grandTotalLine` / `suiteStartedLine`, which were stored **raw from PowerShell pipelines**:

```powershell
$grand = $slice | Where-Object { $_ -match "GRAND TOTAL" } | Select-Object -Last 1
$startLine = @($slice | Where-Object { $_ -match "testing of " } | Select-Object -Last 1) | Select-Object -First 1
```

4. **Root cause:** PowerShell 5.1 wraps pipeline output objects in `PSObject` even when the underlying value is a `System.String` (verified: `$grand -is [System.Management.Automation.PSObject]` → `True`; `GetType()` misleadingly reports `System.String` via PSObject forwarding). `ConvertTo-Json` in PS 5.1 **recursion-hangs on PSObject-wrapped strings** — reproduced in isolation: `[ordered]@{ g = $grand } | ConvertTo-Json -Depth 10` did not return after 180 s, while `ToString()` / `[string]` / `PSObject.BaseObject` variants returned in **1–6 ms**.
5. Consequence: the finalize thread hung at `serializing manifest`; the operator's abort killed the harness in that window; no `manifest.json`, no `manifest_ERROR.json` was ever written. This also explains runs 2/3/4 (identical capture code). The skip-run (`TT01_20260814_234346`) completed because the suite was skipped → `grandTotalLine`/`suiteStartedLine` were empty strings → no hang.
6. Why `buildLine` never hung: it unwraps via `$_.Line` (native string property), so it was not PSObject-wrapped.

## 3. Remediation

1. **Coercion at capture sites** (`Tools\TT01\TT01_Validate.ps1`, suite-evidence phase): every journal line stored into `BuildIdentity.runtime` is now coerced to a native string at assignment (`[string](@(...) | Select-Object -First 1)` for `grand` / `startLine`, `[string]$_.Line` for `failLines`, `[string](...)` for `buildLine`). Root defect eliminated.
2. **Defensive invariant** (`Tools\TT01\TT01_Validators.ps1`): new `ConvertTo-TT01JsonSafe` walker recursively unwraps any `PSObject`-wrapped string in the manifest graph (hashtables, ordered dictionaries, arrays, wrapped scalars) before `ConvertTo-Json`. `Write-TT01Manifest` now serializes through it, so no future pipeline-origin string can re-introduce the hang.
3. **Persistence ordering** (already in place from Phase 2, kept): finalize writes `manifest.json` immediately after the perf gate and `overall=` decision — before evidence copies, baseline update, and binary archive — so the manifest is durable as early as possible and the vulnerable window is minimized.

Files changed (G8 work only):
- `Tools\TT01\TT01_Validate.ps1` — capture-site coercion (Section 2/3)
- `Tools\TT01\TT01_Validators.ps1` — `ConvertTo-TT01JsonSafe` + call site in `Write-TT01Manifest`
- `Tools\25A\G8_Finalize_Test.ps1` — targeted test (same coercion fix for its extraction of the run-5 record)

## 4. Targeted validation (no full TT01 rerun)

`Tools\25A\G8_Finalize_Test.ps1` — runs the **production** `Write-TT01Manifest` on the recorded run-5 graph (17 gates from `gates.jsonl`, identity from `runtime_identity.log`, slice grand line from the actual journal slice), into an isolated `Tools\25A\g8_test\` directory.

Result: **ALL PASS (19/19)**:

- manifest.json written via production function in **110 ms** (previously: hang > 180 s)
- manifest parses; `overall=PASS`; `runId=TT01_20260814_235134`; `gitHead=73e5886`
- 17/17 gates, identical order/names and PASS verdicts as `gates.jsonl`
- identity populated: buildLine tag `2026.08.14 23:54:59`, term `6104`, agent-sandbox path, origin binding, terminal `5.0.0.6104`, TestRunnerEA hash `D1BB10F992AC8E68…`, perf `replayMs=18701`
- run-5 `gates.jsonl` SHA256 unchanged; all four frozen baselines unchanged

## 5. Persistence proof — real harness, reordered finalize

Harness run with all phases skipped (`-Skip compile,suite,replay,activetier,isolation`, launcher script for correct array binding), `TT01_20260815_005616`, **completed in 3 s with a clean exit**:

```
[TT01] FINALIZE: perf gate done (replayMs=0)
[TT01] FINALIZE: overall=FAIL
[TT01] FINALIZE: writing manifest
[TT01] FINALIZE: serializing manifest
[TT01] FINALIZE: writing manifest.json (5501 chars)
[TT01] FINALIZE: manifest.json written
[TT01] FINALIZE: binaries archived
[TT01] FINALIZE: complete - manifest at ...\TT01_20260815_005616\manifest.json
```

`manifest.json` persisted before any further finalize operation. `overall=FAIL` is expected (CSV validators ran without a replay CSV — mechanism test only, NOT a validation record; artifacts retained at `Tools\TT01\artifacts\TT01_20260815_005616\`). `run\gates.jsonl` was restored byte-identical to the Run-5 record afterwards (SHA256 `2E221E7F…` matched backup).

## 6. Baseline integrity

Frozen artifacts verified hash-identical before and after all G8 work (both targeted test and harness proof):

- `Tests\TestRunnerEA.ex5.bak20260812_194614` → `BB6392F49DE0C7EC3E83BF515FC730A1D4A4DA40076B73B7D207E8C59252370F`
- `Tools\TT01\baseline\telemetry_v4_20260130.csv` → `B5AB5FEEAD758A814E903F00A0C62A8DF20AE87B7B63E630CF00408EFA0B2735`
- `Tools\TT01\baseline\baseline.manifest.json` → `82924B28339526B00B5F25161CB78A3B56B8D3909E4833E35B15EE99D726E3A9`
- `Tools\ED01\artifacts\EURUSD_M15\CONTROL_RLHYP01_INTEGRITY\telemetry_v5_20260421.csv` → `2E3941EAD446C79197624977000ECCF08041B50C66918C59EB0B5B99745DB27B`

## 7. G8 verdict

**RESOLVED** (targeted fix). The manifest persistence defect is fully explained (PS 5.1 `ConvertTo-Json` recursion hang on PSObject-wrapped journal strings) and eliminated (capture-site coercion + `ConvertTo-TT01JsonSafe` invariant). Proven with the production function against the recorded run-5 record (110 ms, 19/19 checks) and with the real harness finalize (3 s, manifest-first ordering, clean exit). No EA / telemetry / baseline / gate changes were made. No manifest was manufactured for Run 5; the Run-5 record remains "17/17 gates PASS, manifest absent due to interrupted finalization" — finalization reliability is now fixed for future runs.

## 8. Sprint 25A final status

- G1–G6 implementation: complete; G7: **PASS** (Run-5 17/17 record)
- G8: **RESOLVED** via targeted fix (this document)
- Sprint 25A: **CLOSED** — validation complete on the Run-5 record, finalization defect fixed and proven
- No commits, no push; working tree remains at gitHead `73e5886` with the G8 fix applied locally
- Sprint 25B / 25C: **not started** (per directive)

## 9. Reproduce

1. Root-cause repro: read the run-5 slice `Tools\TT01\artifacts\TT01_20260814_235134\suite_journal_slice.log`, extract the `GRAND TOTAL` line via `Where-Object | Select-Object`, serialize with `ConvertTo-Json -Depth 10` (hangs); serialize `[string]$line` (1–6 ms).
2. Targeted test: `powershell -NoProfile -ExecutionPolicy Bypass -File Tools\25A\G8_Finalize_Test.ps1` → ALL PASS.
3. Harness proof: run `Tools\TT01\TT01_Validate.ps1` with all phases skipped via a launcher passing `-Skip` as an array; expect manifest written first and exit in seconds.
