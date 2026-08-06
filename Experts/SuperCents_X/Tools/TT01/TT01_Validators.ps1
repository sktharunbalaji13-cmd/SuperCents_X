# TT01_Validators.ps1 - TT01 Platform Validation Harness: CSV validators (dot-sourced by TT01_Validate.ps1)
# Each validator returns a [pscustomobject] @{ Name; Pass; Details = [string[]] }.

$script:TT01_HEADER_V31 = @(
    "schemaVersion","configFingerprint","timestamp","symbol","timeframe","eaVersion","decisionId","direction","confidence",
    "structureRaw","structureWeight","structureContribution",
    "obRaw","obWeight","obContribution",
    "fvgRaw","fvgWeight","fvgContribution",
    "trendRaw","trendWeight","trendContribution",
    "liquidityRaw","liquidityWeight","liquidityContribution",
    "pdRaw","pdWeight","pdContribution",
    "validatorResults","confThreshold","newDecision","legacyDecision","decisionMatch","directionMatch",
    "legacyConfidence","newConfidence","disabledValidators","outcomeSource","outcome","rMultiple","barsHeld",
    "exitReason","entryPrice","exitPrice","actualOutcome","actualOutcomeSource",
    "scoreArchitecture","telemetryArchitecture","evidenceContract","confidenceModel","componentData",
    "firedRuleId","ruleName","ruleScore","ruleConfidence","ruleEvidenceCount","ruleEvidenceIds",
    "trendAligned","layerStructural","layerLiquidity","layerConfirmation","layerTotal",
    "hasBOS","hasCHOCH","hasOrderBlock","hasFVG","hasProtectedPoint","hasLiquiditySweep","signalTime",
    "layerOrderBlock","layerFVG","fvgClass","fvgSize","fvgStrength","fvgCreatedTime","fvgFillTime"
)

$script:TT01_NUMERIC = @(
    "confidence",    "structureRaw","structureWeight","structureContribution",
    "obRaw","obWeight","obContribution",
    "fvgRaw","fvgWeight","fvgContribution",
    "trendRaw","trendWeight","trendContribution",
    "liquidityRaw","liquidityWeight","liquidityContribution",
    "pdRaw","pdWeight","pdContribution",
    "confThreshold","legacyConfidence","newConfidence",
    "rMultiple","barsHeld","entryPrice","exitPrice",
    "firedRuleId","ruleScore","ruleConfidence","ruleEvidenceCount",
    "layerStructural","layerLiquidity","layerConfirmation","layerTotal","layerOrderBlock","layerFVG"
)

$script:TT01_FLAGS = @(
    "newDecision","legacyDecision","decisionMatch","directionMatch",
    "outcomeSource","outcome","actualOutcome","actualOutcomeSource"
)

$script:TT01_BINARY = @(
    "componentData","trendAligned","direction",
    "hasBOS","hasCHOCH","hasOrderBlock","hasFVG","hasProtectedPoint","hasLiquiditySweep"
)

$script:TT01_TIME = @("timestamp","signalTime","fvgCreatedTime","fvgFillTime")

$script:TT01_TOL = 1e-6

function New-TT01Result {
    param([string]$Name, [bool]$Pass, [string[]]$Details = @())
    [pscustomobject]@{ Name = $Name; Pass = $Pass; Details = @($Details) }
}

function Get-TT01CsvHash {
    param([string]$Path)
    (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
}

function Get-TT01Counters {
    param([string]$Path)
    $rows = Import-Csv -LiteralPath $Path
    $ruleCounts = @{}
    foreach ($r in $rows) { $k = if ($r.ruleName) { $r.ruleName } else { "(none)" }; $ruleCounts[$k] = 1 + $ruleCounts[$k] }
    $outcomeCounts = @{}
    foreach ($r in $rows) { $k = if ($r.outcome) { $r.outcome } else { "(none)" }; $outcomeCounts[$k] = 1 + $outcomeCounts[$k] }
    $ids = @{}
    foreach ($r in $rows) { $ids[$r.decisionId] = $true }
    [ordered]@{
        rows             = $rows.Count
        decisionIdsUnique = $ids.Count
        ruleName         = $ruleCounts
        outcome          = $outcomeCounts
        componentData1   = @($rows | Where-Object { $_.componentData -eq "1" }).Count
        firstSignalTime  = $rows[0].signalTime
        lastSignalTime   = $rows[-1].signalTime
    }
}

function Test-TT01Contract {
    param([string]$Path)
    $detail = [System.Collections.Generic.List[string]]::new()
    $fail = 0
    $headerLine = Get-Content -LiteralPath $Path -TotalCount 1
    $cols = $headerLine.Split(",")
    if ($cols.Count -ne 75) { $fail++; $detail.Add("header column count $($cols.Count) != 75") }
    foreach ($i in 0..([Math]::Min($cols.Count, $script:TT01_HEADER_V31.Count) - 1)) {
        if ($cols[$i] -ne $script:TT01_HEADER_V31[$i]) { $fail++; $detail.Add("column[$i] '$($cols[$i])' != '$($script:TT01_HEADER_V31[$i])'" ) }
    }
    $rows = Import-Csv -LiteralPath $Path
    foreach ($c in $script:TT01_NUMERIC) {
        if (-not $cols.Contains($c)) { $fail++; $detail.Add("numeric column '$c' missing from header"); continue }
        foreach ($r in $rows) {
            $d = 0.0
            if (-not [double]::TryParse($r.$c, [ref]$d)) { $fail++; $detail.Add("non-numeric '$c' value '$($r.$c)' row '$($r.signalTime)'"); break }
        }
    }
    foreach ($c in $script:TT01_FLAGS) {
        foreach ($r in $rows) {
            if ($r.$c -ne "0" -and $r.$c -ne "1" -and $r.$c -ne "2") { $fail++; $detail.Add("flag '$c' value '$($r.$c)' not in {0,1,2} row '$($r.signalTime)'"); break }
        }
    }
    foreach ($c in $script:TT01_BINARY) {
        foreach ($r in $rows) {
            if ($r.$c -ne "1" -and $r.$c -ne "2") { $fail++; $detail.Add("binary '$c' value '$($r.$c)' not in {1,2} row '$($r.signalTime)'"); break }
        }
    }
    foreach ($c in $script:TT01_TIME) {
        foreach ($r in $rows) {
            $t = [datetime]::MinValue
            if (-not [datetime]::TryParse($r.$c, [ref]$t)) { $fail++; $detail.Add("bad datetime '$c' value '$($r.$c)' row '$($r.signalTime)'"); break }
        }
    }
    $schemaBad = @($rows | Where-Object { $_.schemaVersion -ne "4" }).Count
    if ($schemaBad -gt 0) { $fail++; $detail.Add("$schemaBad rows with schemaVersion != 4") }
    $fp = @($rows | ForEach-Object { $_.configFingerprint } | Sort-Object -Unique).Count
    if ($fp -ne 1) { $fail++; $detail.Add("configFingerprint not constant ($fp distinct)") }
    $timeBad = @($rows | Where-Object { $_.signalTime -notmatch "^\d{4}\.\d{2}\.\d{2} \d{2}:\d{2}" }).Count
    if ($timeBad -gt 0) { $fail++; $detail.Add("$timeBad rows with malformed signalTime") }
    if ($fail -eq 0) { $detail.Add("header 75/75 exact, schemaVersion=4, all numerics/flags/times parse, fingerprint constant") }
    New-TT01Result -Name "TELEMETRY-CONTRACT" -Pass ($fail -eq 0) -Details $detail.ToArray()
}

function Test-TT01Evidence {
    param([string]$Path)
    $detail = [System.Collections.Generic.List[string]]::new()
    $fail = 0
    $rows = Import-Csv -LiteralPath $Path
    $tol = $script:TT01_TOL
    $splitBad = 0
    foreach ($r in $rows) {
        $s = [double]$r.structureRaw; $ob = [double]$r.obRaw; $fv = [double]$r.fvgRaw; $lq = [double]$r.liquidityRaw; $pd = [double]$r.pdRaw; $tr = [double]$r.trendRaw
        $lS = [double]$r.layerStructural; $lO = [double]$r.layerOrderBlock; $lF = [double]$r.layerFVG; $lL = [double]$r.layerLiquidity
        $cS = [double]$r.structureContribution; $cO = [double]$r.obContribution; $cF = [double]$r.fvgContribution; $cL = [double]$r.liquidityContribution; $cT = [double]$r.trendContribution
        $wS = [double]$r.structureWeight; $wO = [double]$r.obWeight; $wF = [double]$r.fvgWeight; $wL = [double]$r.liquidityWeight; $wT = [double]$r.trendWeight
        $ta = [int]$r.trendAligned
        $rule = ([math]::Abs($s + $ob + $fv - $lS) -le $tol) -and ([math]::Abs($ob - $lO) -le $tol) -and ([math]::Abs($fv - $lF) -le $tol) -and `
                ([math]::Abs($lq - $lL) -le $tol) -and ([math]::Abs($pd) -le $tol) -and `
                ([math]::Abs($cS - $s * $wS / 100.0) -le $tol) -and ([math]::Abs($cO - $ob * $wO / 100.0) -le $tol) -and `
                ([math]::Abs($cF - $fv * $wF / 100.0) -le $tol) -and ([math]::Abs($cL - $lq * $wL / 100.0) -le $tol) -and `
                ([math]::Abs($cT - $tr * $wT / 100.0) -le $tol) -and `
                ((($ta -eq 2) -and ($tr -gt 0.0)) -or (($ta -ne 2) -and ([math]::Abs($tr) -le $tol)))
        $eval = ([int]$cS + [int]$cO + [int]$cF -eq [int]$lS) -and ([int]$cO -eq [int]$lO) -and ([int]$cF -eq [int]$lF) -and `
                ([int]$cL -eq [int]$lL) -and ([int]$cT + [int]$pd -eq [int]$r.layerConfirmation)
        if (-not ($rule -or $eval)) { $splitBad++ }
    }
    if ($splitBad -gt 0) { $fail++; $detail.Add("split invariant violated on $splitBad/$($rows.Count) rows") } else { $detail.Add("split invariant (rule|eval) holds on $($rows.Count)/$($rows.Count) rows") }

    foreach ($c in @("structureRaw","obRaw","fvgRaw","trendRaw","liquidityRaw")) {
        $u = @($rows | ForEach-Object { [double]$_.$c } | Sort-Object -Unique).Count
        if ($u -le 1) { $fail++; $detail.Add("raw '$c' constant ($u unique) - telemetry inert") }
    }
    $pdU = @($rows | ForEach-Object { [double]$_.pdRaw } | Sort-Object -Unique).Count
    $detail.Add("pdRaw unique=$pdU (PD family not wired at decision time yet - DD02/DD05 target; not gated)")
    foreach ($c in @("layerOrderBlock","layerFVG","layerLiquidity","layerStructural","layerTotal","layerConfirmation")) {
        $u = @($rows | ForEach-Object { [double]$_.$c } | Sort-Object -Unique).Count
        if ($u -le 1) { $fail++; $detail.Add("layer '$c' constant ($u unique)") }
    }
    $ppRows = @($rows | Where-Object { $_.hasProtectedPoint -eq "2" }).Count
    if ($ppRows -lt 1) { $fail++; $detail.Add("hasProtectedPoint never '2' (unreachable)") } else { $detail.Add("hasProtectedPoint '2' on $ppRows rows") }

    $clsBad = 0; $timeBad = 0; $fillBad = 0
    foreach ($r in $rows) {
        $isFVG = ($r.hasFVG -eq "2")
        if (-not $isFVG) {
            if ($r.fvgClass -ne "UNKNOWN" -or $r.fvgSize -ne "UNKNOWN" -or $r.fvgStrength -ne "UNKNOWN" -or
                $r.fvgCreatedTime -ne "1970.01.01 00:00" -or $r.fvgFillTime -ne "1970.01.01 00:00") { $clsBad++ }
        } else {
            $created = [datetime]::MinValue; [datetime]::TryParse($r.fvgCreatedTime, [ref]$created) | Out-Null
            $fill = [datetime]::MinValue; [datetime]::TryParse($r.fvgFillTime, [ref]$fill) | Out-Null
            if ($created -le [datetime]::Parse("1970.01.01")) { $timeBad++ }
            if ($fill -gt [datetime]::Parse("1970.01.01") -and $fill -lt $created) { $fillBad++ }
        }
    }
    if ($clsBad -gt 0) { $fail++; $detail.Add("$clsBad non-FVG rows claim classifier values") }
    if ($timeBad -gt 0) { $fail++; $detail.Add("$timeBad FVG rows with missing fvgCreatedTime") }
    if ($fillBad -gt 0) { $fail++; $detail.Add("$fillBad rows with fvgFillTime < fvgCreatedTime") }

    $ruleBad = @($rows | Where-Object {
        ($_.firedRuleId -gt "0" -and ($_.ruleName -eq "" -or $_.ruleEvidenceCount -eq "0")) -or
        ($_.firedRuleId -eq "0" -and ($_.ruleName -ne "" -or $_.ruleEvidenceCount -ne "0"))
    }).Count
    if ($ruleBad -gt 0) { $fail++; $detail.Add("$ruleBad rows violate firedRuleId/ruleName/ruleEvidenceCount consistency") }

    if ($fail -eq 0) { $detail.Add("all evidence invariants hold") }
    New-TT01Result -Name "EVIDENCE-REGRESSION" -Pass ($fail -eq 0) -Details $detail.ToArray()
}

function Test-TT01Behavior {
    param([string]$RunPath, [string]$BasePath, [string[]]$AllowDelta = @(), [int]$ExpectedRows = 0, [string[]]$AllowDecisionIds = @())
    $detail = [System.Collections.Generic.List[string]]::new()
    $fail = 0
    $run = Import-Csv -LiteralPath $RunPath
    $base = Import-Csv -LiteralPath $BasePath
    if ($ExpectedRows -gt 0 -and $run.Count -ne $ExpectedRows) {
        $fail++
        $detail.Add("row count $($run.Count) != expected $ExpectedRows")
        New-TT01Result -Name "BEHAVIOR-REGRESSION" -Pass $false -Details $detail.ToArray()
        return
    }
    if ($ExpectedRows -eq 0 -and $run.Count -ne $base.Count) {
        $fail++
        $detail.Add("row count $($run.Count) != baseline $($base.Count) (no -ExpectedRows given)")
        New-TT01Result -Name "BEHAVIOR-REGRESSION" -Pass $false -Details $detail.ToArray()
        return
    }
    $cols = $base[0].PSObject.Properties.Name

    #--- decision identity invariant (always enforced): the same logical
    #--- decisions must be compared (sequence, time, config, symbol, timeframe).
    $identityBad = 0
    foreach ($k in @("decisionId","signalTime","configFingerprint","symbol","timeframe")) {
        $d = 0
        for ($i = 0; $i -lt $run.Count; $i++) { if ($run[$i].$k -ne $base[$i].$k) { $d++ } }
        if ($d -gt 0) { $identityBad++; $detail.Add("identity '$k' differs on $d rows (sequence shifted - FAIL)") }
    }
    if ($identityBad -gt 0) { $fail++ }
    else { $detail.Add("decision identity invariant holds: decisionId/signalTime/configFingerprint/symbol/timeframe identical on all $($run.Count) rows") }

    if ($AllowDecisionIds.Count -gt 0) {
        #--- row-rooted localization: only the allowlisted decisions may differ;
        #--- every other row must be byte-identical on ALL columns.
        $allowed = @{}
        foreach ($id in $AllowDecisionIds) { $allowed[$id] = $true }
        $changedIds = @{}
        $unexpected = 0; $attributionBad = 0; $changedTotal = 0
        foreach ($i in 0..($run.Count - 1)) {
            $diff = @($cols | Where-Object { $run[$i].$_ -ne $base[$i].$_ })
            if ($diff.Count -eq 0) { continue }
            $changedTotal++
            $changedIds[$run[$i].decisionId] = $true
            if (-not $allowed.ContainsKey($run[$i].decisionId)) {
                $unexpected++
                if ($unexpected -le 5) { $detail.Add("unexpected changed row $i (decisionId $($run[$i].decisionId), rule $($run[$i].ruleName)) not in allowlist") }
            } else {
                #--- attribution invariant: the change must originate from the
                #--- liquidity cascade (sweep flag, liquidity rule, level evidence,
                #--- or the legacy confidence echo of a changed decision).
                $liq = ($run[$i].hasLiquiditySweep -ne $base[$i].hasLiquiditySweep) -or
                       ($run[$i].ruleName -like "LIQUIDITY_*") -or ($base[$i].ruleName -like "LIQUIDITY_*") -or
                       ($run[$i].ruleEvidenceIds -ne $base[$i].ruleEvidenceIds) -or
                       ($run[$i].legacyConfidence -ne $base[$i].legacyConfidence)
                if (-not $liq) {
                    $attributionBad++
                    if ($attributionBad -le 5) { $detail.Add("decisionId $($run[$i].decisionId) changed without liquidity attribution (rule $($base[$i].ruleName) -> $($run[$i].ruleName))") }
                }
            }
        }
        $missing = @($AllowDecisionIds | Where-Object { -not $changedIds.ContainsKey($_) }).Count
        if ($unexpected -gt 0) { $fail++; $detail.Add("completeness FAIL: $unexpected changed rows outside the allowlist") }
        if ($missing -gt 0) { $fail++; $detail.Add("completeness FAIL: $missing allowlisted decisions did not change") }
        if ($attributionBad -gt 0) { $fail++; $detail.Add("attribution FAIL: $attributionBad allowed decisions not liquidity-attributable") }
        if ($unexpected -eq 0 -and $missing -eq 0) { $detail.Add("completeness invariant holds: changed rows ($changedTotal) == allowlist ($($AllowDecisionIds.Count))") }
        if ($attributionBad -eq 0) { $detail.Add("attribution invariant holds: all $($AllowDecisionIds.Count) allowed decisions trace to the liquidity cascade") }
        $detail.Add("unchanged decisions: $($run.Count - $changedTotal)/$($run.Count) byte-identical on all columns")
        $cRun = Get-TT01Counters $RunPath
        $cBase = Get-TT01Counters $BasePath
        foreach ($rule in @($cBase.ruleName.Keys + @($cRun.ruleName.Keys) | Sort-Object -Unique)) {
            $b = if ($cBase.ruleName.ContainsKey($rule)) { $cBase.ruleName[$rule] } else { 0 }
            $r = if ($cRun.ruleName.ContainsKey($rule)) { $cRun.ruleName[$rule] } else { 0 }
            if ($r -ne $b) { $detail.Add("rule '$rule' count $b -> $r (inside allowlisted decisions)") }
        }
        New-TT01Result -Name "BEHAVIOR-REGRESSION" -Pass ($fail -eq 0) -Details $detail.ToArray()
        return
    }

    #--- legacy column-level comparison (no allowlist) / -AllowDelta path
    $rowDelta = $run.Count -ne $base.Count
    $diffCols = @()
    if ($rowDelta) {
        # decisionId-aligned comparison: shared ids must be byte-identical on
        # non-allowlisted columns; added/missing rows are permitted only when
        # their rule is allowlisted (e.g. LIQUIDITY_BOS_* during DD03).
        $baseById = @{}; foreach ($r in $base) { $baseById[$r.decisionId] = $r }
        $runById  = @{}; foreach ($r in $run)  { $runById[$r.decisionId]  = $r }
        $sharedBad = 0; $added = 0; $missing = 0
        foreach ($id in $runById.Keys) {
            if (-not $baseById.ContainsKey($id)) { $added++; continue }
            foreach ($c in $cols) {
                if ($AllowDelta -contains $c) { continue }
                if ($runById[$id].$c -ne $baseById[$id].$c) {
                    $sharedBad++
                    if ($sharedBad -le 5) { $detail.Add("shared decisionId $id differs on column $c") }
                }
            }
        }
        foreach ($id in $baseById.Keys) { if (-not $runById.ContainsKey($id)) { $missing++ } }
        if ($sharedBad -gt 0) { $fail++; $detail.Add("$sharedBad column diffs on shared decisionIds (row-set delta)") }
        else { $detail.Add("all non-allowlisted columns identical on $($runById.Count - $added) shared decisions") }
        foreach ($id in $runById.Keys) {
            if ($baseById.ContainsKey($id)) { continue }
            if ($AllowDelta -notcontains $runById[$id].ruleName) { $fail++; $detail.Add("added decisionId $id with non-allowlisted rule '$($runById[$id].ruleName)'") }
        }
        foreach ($id in $baseById.Keys) {
            if ($runById.ContainsKey($id)) { continue }
            if ($AllowDelta -notcontains $baseById[$id].ruleName) { $fail++; $detail.Add("missing baseline decisionId $id with non-allowlisted rule '$($baseById[$id].ruleName)'") }
        }
        $detail.Add("row-set delta: +$added added, -$missing missing (rows $($base.Count) -> $($run.Count))")
    } else {
        foreach ($c in $cols) {
            $d = 0
            for ($i = 0; $i -lt $run.Count; $i++) { if ($run[$i].$c -ne $base[$i].$c) { $d++ } }
            if ($d -gt 0) { $diffCols += "$c=$d" }
        }
        if ($diffCols.Count -eq 0) {
            $detail.Add("all $($cols.Count) columns byte-identical across $($run.Count) rows")
        } else {
            $bad = @($diffCols | Where-Object { $name = ($_ -split "=")[0]; $AllowDelta -notcontains $name })
            foreach ($d in $diffCols) { $detail.Add("differing column: $d") }
            if ($bad.Count -gt 0) { $fail++ }
            else { $detail.Add("differences confined to allowlisted columns: $($AllowDelta -join ',')") }
        }
    }
    $cRun = Get-TT01Counters $RunPath
    $cBase = Get-TT01Counters $BasePath
    if ($rowDelta) {
        if ($cRun.decisionIdsUnique -lt $cBase.decisionIdsUnique) {
            $detail.Add("decisionIdsUnique $($cRun.decisionIdsUnique) < baseline $($cBase.decisionIdsUnique)")
        }
    } else {
        foreach ($k in @("rows","decisionIdsUnique","firstSignalTime","lastSignalTime","componentData1")) {
            if ($cRun.$k -ne $cBase.$k) { $fail++; $detail.Add("counter '$k' $($cRun.$k) != baseline $($cBase.$k)") }
        }
    }
    foreach ($rule in @($cBase.ruleName.Keys + @($cRun.ruleName.Keys) | Sort-Object -Unique)) {
        $b = if ($cBase.ruleName.ContainsKey($rule)) { $cBase.ruleName[$rule] } else { 0 }
        $r = if ($cRun.ruleName.ContainsKey($rule)) { $cRun.ruleName[$rule] } else { 0 }
        if ($r -ne $b) {
            if ($AllowDelta -contains $rule) { $detail.Add("rule '$rule' count $b -> $r (allowlisted)") }
            else { $fail++; $detail.Add("rule '$rule' count $r != baseline $b") }
        }
    }
    if (-not $rowDelta) {
        foreach ($o in @($cBase.outcome.Keys + @($cRun.outcome.Keys) | Sort-Object -Unique)) {
            $b = if ($cBase.outcome.ContainsKey($o)) { $cBase.outcome[$o] } else { 0 }
            $r = if ($cRun.outcome.ContainsKey($o)) { $cRun.outcome[$o] } else { 0 }
            if ($r -ne $b) {
                $allowed = $true
                for ($i = 0; $i -lt $run.Count; $i++) {
                    if ($run[$i].outcome -ne $base[$i].outcome) {
                        if ($AllowDelta -notcontains $run[$i].ruleName -and $AllowDelta -notcontains $base[$i].ruleName) { $allowed = $false }
                    }
                }
                if ($allowed) { $detail.Add("outcome '$o' count $b -> $r (confined to allowlisted rules)") }
                else { $fail++; $detail.Add("outcome '$o' count $r != baseline $b") }
            }
        }
    }
    if ($fail -eq 0) {
        $detail.Add("counters match: $($cRun.decisionIdsUnique) unique decisions, rules $($cRun.ruleName.Count), outcomes $($cRun.outcome.Count)")
    }
    New-TT01Result -Name "BEHAVIOR-REGRESSION" -Pass ($fail -eq 0) -Details $detail.ToArray()
}
