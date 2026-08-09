# Developer Guide — Build & Tester Tooling

Operational recipes for building and verifying SuperCents_X on this machine.

## Compiling with MetaEditor (critical)

MetaEditor is a **GUI-subsystem process**. In PowerShell, `&` (and pipe redirection)
**returns immediately** without waiting — the compile never runs, stdout is empty,
and `$LASTEXITCODE` is blank. Any "result: 0 errors" you see afterwards is a
**stale log file**, not the current build.

Wrong (silently does nothing):
```powershell
& $me /compile:"...SuperCents_X.mq5"
```

Right (blocks until finished):
```powershell
$me  = "C:\Program Files\MetaTrader 5\metaeditor64.exe"
$dir = "...\MQL5"
$p   = Start-Process $me -ArgumentList "/log","/compile:`"$dir\Experts\SuperCents_X\SuperCents_X.mq5`"" -Wait -PassThru
"exit: $($p.ExitCode)"
Get-Content "$dir\Experts\SuperCents_X\SuperCents_X.log" | Select-Object -Last 1
Get-Item "$dir\Experts\SuperCents_X\SuperCents_X.ex5" | Select-Object LastWriteTime
```

**Verify three things before trusting a build:**
1. Exit code / log tail says `0 errors` (log `LastWriteTime` is NOW, not old).
2. `.ex5` `LastWriteTime` advanced past the source edit time.
3. Only then launch the tester run.

A 900 ms "compile" is a no-op; a real SuperCents_X compile takes ~10-13 s,
TestRunnerEA ~30-40 s. Always rebuild both EAs after interface changes —
the tester runs the `.ex5`, so a stale binary silently runs old logic.

### MQL5 syntax pitfalls seen in this project
- **No ternary `?:` operator** — `x = (cond) ? a : b` fails with
  `error 252: ':' - invalid cast operation`. Use if/else (e.g., provider
  binding in the ctor body after a shadow-default init list).
- Class members are initialized in **declaration order**, regardless of
  init-list order; validators that capture provider pointers in their own
  constructors must receive them at construction time (see SymbolContext).

## Headless tester runs

The terminal must be launched with the preset as a `/config:` argument —
a bare positional ini path is silently ignored and no testing starts:

```powershell
$t64 = "C:\Program Files\MetaTrader 5\terminal64.exe"
Start-Process $t64 -ArgumentList "/config:`"$ini`""
```

Acceptance = terminal log shows `launched with <ini>` then
`automatic testing started`, completion = `last test passed` / `shutdown with 0`.

- Preset inis live in `Experts\SuperCents_X\Presets\*.ini`; the test-suite ini
  is copied to `MQL5\Profiles\Tester\` before launch.
- EA inputs come from the UTF-16 LE `.set` in `MQL5\Profiles\Tester\`
  (overwrite it per run; `EntryMode=1` SHADOW / `=2` NEW / `=0` LEGACY).
- SuperCents_X runs finish in ~27 s (480 bars); the 451-test suite ~20 s.

## Reading results

- Agent journal `...\Tester\<instance>\Agent-127.0.0.1-3000\logs\<date>.log`
  (UTF-16 LE) **accumulates every run** — always take the **last**
  `GRAND TOTAL` / `Shadow Mode Summary` match; never the first.
- `some error after pass finished` is benign; the real signal is `GRAND TOTAL`.
- 4 `metatester64` worker processes persist between runs and reject
  `taskkill` (Access denied) — harmless. `Stop-Process terminal64` is all
  that is needed between runs.
- Telemetry CSV in `Terminal\Common\Files\Telemetry\` **appends** across
  runs (file is not truncated per run) — slice the last N rows per run.

## Telemetry parity checks

To prove a change is behavior-neutral: run the same preset before/after,
compare the last 480-row block against the previous run's block across
`newConfidence`, `decisionMatch`, `legacyConfidence`, `validatorResults`.
Byte-identical = the shadow pipeline is untouched.
