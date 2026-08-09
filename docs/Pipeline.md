# Pipeline — SuperCents_X v0.8.0

## Execution Order (Engine.mqh)

The pipeline runs once per tick in `ProcessTick()`. Each step calls the next module's `Update()`.

```
Step  Module                   Input Arrays            Consumes
----  -----------------------  ----------------------  -------------------------
1     SwingDetector.Update     high[], low[], time[]   (none)
2     StructuralPivotEngine    —                       CSwingDetector*
3     BOSDetector.Update       close[], time[]         CStructuralPivotEngine*
4     TrendState.Update        —                       CBOSDetector*
5     ProtectedPointManager    time[]                  CStructuralPivotEngine*,
                              (1-element barrier)     CBOSDetector*, CTrendState*
6     CHOCHDetector.Update     close[], time[]         CTrendState*,
                                                       CProtectedPointManager*
7     OrderBlockDetector       open[], high[],         CCHOCHDetector*,
      .Update                  low[], close[],         CTrendState*,
                               time[]                  CProtectedPointManager*
```

## Bar Array Convention

All price arrays (`open[]`, `high[]`, `low[]`, `close[]`, `time[]`) use MQL5 convention:

- **Index 0** = current (newest) bar
- **Index N-1** = oldest bar in the window

Modules process from index 2 upward (newer bars first).

## Incremental Processing

The pipeline processes the full bar window on every call. Each module maintains internal state to avoid reprocessing previously seen bars. The `rates_total` parameter tells each module the size of the current window.

## Module Communication

No module calls another module's `Update()`. The Engine controls the sequence.
Modules read each other's state only through public `Get*()` accessors.
