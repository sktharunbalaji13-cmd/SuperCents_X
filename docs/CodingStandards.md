# Coding Standards — SuperCents_X

## File Conventions

- One class per `.mqh` file.
- Filename matches the class name (e.g. `SwingDetector.mqh` → `CSwingDetector`).
- Standard header comment block at top of every file.

## Naming

| Element | Convention | Example |
|---|---|---|
| Classes | `C` prefix, PascalCase | `CSwingDetector` |
| Methods | PascalCase | `GetOrderBlockCount()` |
| Parameters | camelCase | `chochDetector` |
| Member variables | `m_` prefix | `m_initialized` |
| Constants | `UPPER_SNAKE_CASE` | `SWING_STRENGTH` |
| Enums | `UPPER_SNAKE_CASE` | `TREND_BULLISH` |
| Structs | PascalCase | `OrderBlock` |
| Macros | `UPPER_SNAKE_CASE` | `MODULE_SWING_DETECTOR` |
| File names | PascalCase | `OrderBlockDetector.mqh` |

## Module Contract

Every module must implement:

```
bool Init(void)
void Shutdown(void)
bool IsInitialized(void) const
```

## Lifecycle Rules

1. `Init()` before `Update()`. Calling `Update()` before `Init()` is undefined.
2. `Shutdown()` before destruction if `Init()` was called.
3. After `Shutdown()`, the module can be re-initialized with another `Init()`.

## Memory

- No dynamic allocation inside `Update()` after `Init()`.
- All buffers allocated in `Init()` are freed in `Shutdown()`.
- No global or static state that persists across instances.

## Error Handling

- `Init()` returns `false` on failure.
- Accessor methods return `false` when the requested index is out of range.
- No exceptions. No alerts. No `Print()` inside structure modules (use `CLogger`).

## Comments

No comments inside method bodies. Self-documenting code via descriptive names.
If an algorithm requires explanation, use a single comment at the method level.

## Dependencies

- A module may depend only on modules earlier in the pipeline.
- No circular dependencies.
- All cross-module dependencies are passed via pointer in `Update()`.

## Frozen Modules

Modules marked as frozen in a version tag must not be modified except for:
- Critical bug fixes supported by evidence (test failure, crash, data corruption).
- Changes must be reviewed and the version tag updated.
