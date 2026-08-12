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

# Sprint 22 RL-HYP-01: schema v5 appends the 3 swing-gate columns (append-only over v3.1).
$script:TT01_HEADER_V5 = @($script:TT01_HEADER_V31) + @("swingQualifyingId","swingAmplitude","gateDecision")

# Schema-recording columns: exempted from behavior byte-compare against the frozen
# v4 baseline (B7). The version flip 4 -> 5 and the sentinel gate values record the
# Sprint 22 policy (gate OFF at tier 0.0 => surfacing integers equal to the legacy
# TelemetryRow beyond these columns); byte-identity must hold on every other column.
$script:TT01_SCHEMA_RECORDING = @("schemaVersion","swingQualifyingId","swingAmplitude","gateDecision")

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
    if ($cols.Count -ne $script:TT01_HEADER_V5.Count) { $fail++; $detail.Add("header column count $($cols.Count) != $($script:TT01_HEADER_V5.Count) (v5)") }
    foreach ($i in 0..([Math]::Min($cols.Count, $script:TT01_HEADER_V5.Count) - 1)) {
        if ($cols[$i] -ne $script:TT01_HEADER_V5[$i]) { $fail++; $detail.Add("column[$i] '$($cols[$i])' != '$($script:TT01_HEADER_V5[$i])'" ) }
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
    $schemaBad = @($rows | Where-Object { $_.schemaVersion -ne "5" }).Count
    if ($schemaBad -gt 0) { $fail++; $detail.Add("$schemaBad rows with schemaVersion != 5") }
    foreach ($r in $rows) {
        $q = 0; $a = 0.0
        if (-not [int]::TryParse($r.swingQualifyingId, [ref]$q)) { $fail++; $detail.Add("non-integer swingQualifyingId '$($r.swingQualifyingId)' row '$($r.signalTime)'"); break }
        if (-not [double]::TryParse($r.swingAmplitude, [ref]$a)) { $fail++; $detail.Add("non-numeric swingAmplitude '$($r.swingAmplitude)' row '$($r.signalTime)'"); break }
        if ($r.gateDecision -notin @("OFF","ADMIT","GATE-OUT")) { $fail++; $detail.Add("bad gateDecision '$($r.gateDecision)' row '$($r.signalTime)'"); break }
    }
    #--- Default harness profile runs the gate at tier 0.0 (OFF): the 3 gate
    #--- columns must therefore carry their sentinel recordings on every row,
    #--- proving the default configuration surfaces the legacy TelemetryRow
    #--- unchanged (byte-identity contract, protocol 11.3a).
    $sentinelBad = @($rows | Where-Object { $_.swingQualifyingId -ne "0" -or $_.swingAmplitude -ne "0.00000000" -or $_.gateDecision -ne "OFF" }).Count
    if ($sentinelBad -gt 0) { $fail++; $detail.Add("$sentinelBad rows with non-sentinel gate columns (tier 0.0 must record 0/0.00000000/OFF)") }
    $fp = @($rows | ForEach-Object { $_.configFingerprint } | Sort-Object -Unique).Count
    if ($fp -ne 1) { $fail++; $detail.Add("configFingerprint not constant ($fp distinct)") }
    $timeBad = @($rows | Where-Object { $_.signalTime -notmatch "^\d{4}\.\d{2}\.\d{2} \d{2}:\d{2}" }).Count
    if ($timeBad -gt 0) { $fail++; $detail.Add("$timeBad rows with malformed signalTime") }
    if ($fail -eq 0) { $detail.Add("header $($script:TT01_HEADER_V5.Count)/$($script:TT01_HEADER_V5.Count) exact (v5 = v3.1 + 3 gate columns), schemaVersion=5, gate sentinels OFF, all numerics/flags/times parse, fingerprint constant") }
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
    #--- During row-rooted localization (-AllowDecisionIds) configFingerprint is
    #--- exempted: the fingerprint records the routing policy (e.g. DD05
    #--- per-family admission floors) and is expected to change globally between
    #--- baselines; its constancy WITHIN the run is verified by the CONTRACT
    #--- gate, and sequence identity is proven by the remaining keys.
    $identityKeys = @("decisionId","signalTime","configFingerprint","symbol","timeframe")
    if ($AllowDecisionIds.Count -gt 0) { $identityKeys = @("decisionId","signalTime","symbol","timeframe") }
    $identityBad = 0
    foreach ($k in $identityKeys) {
        $d = 0
        for ($i = 0; $i -lt $run.Count; $i++) { if ($run[$i].$k -ne $base[$i].$k) { $d++ } }
        if ($d -gt 0) { $identityBad++; $detail.Add("identity '$k' differs on $d rows (sequence shifted - FAIL)") }
    }
    if ($AllowDecisionIds.Count -gt 0) {
        $fpDiff = 0
        for ($i = 0; $i -lt $run.Count; $i++) { if ($run[$i].configFingerprint -ne $base[$i].configFingerprint) { $fpDiff++ } }
        if ($fpDiff -gt 0) { $detail.Add("configFingerprint differs on $fpDiff rows (expected policy recording; constancy verified by CONTRACT gate)") }
    }
    if ($identityBad -gt 0) { $fail++ }
    else { $detail.Add("decision identity invariant holds: $($identityKeys -join '/') identical on all $($run.Count) rows") }

    if ($AllowDecisionIds.Count -gt 0) {
        #--- row-rooted localization: only the allowlisted decisions may differ;
        #--- every other row must be byte-identical on ALL columns.
        $allowed = @{}
        foreach ($id in $AllowDecisionIds) { $allowed[$id] = $true }
        $changedIds = @{}
        $unexpected = 0; $attributionBad = 0; $changedTotal = 0
        foreach ($i in 0..($run.Count - 1)) {
            $diff = @($cols | Where-Object {
                $c = $_
                if ($AllowDecisionIds.Count -gt 0 -and $c -eq "configFingerprint") { return $false }
                if ($script:TT01_SCHEMA_RECORDING -contains $c) { return $false }
                return $run[$i].$c -ne $base[$i].$c
            })
            if ($diff.Count -eq 0) { continue }
            $changedTotal++
            $changedIds[$run[$i].decisionId] = $true
            if (-not $allowed.ContainsKey($run[$i].decisionId)) {
                $unexpected++
                if ($unexpected -le 5) { $detail.Add("unexpected changed row $i (decisionId $($run[$i].decisionId), rule $($run[$i].ruleName)) not in allowlist") }
            } else {
                #--- attribution invariant: the change must originate from the
                #--- liquidity cascade (sweep flag, liquidity rule, level evidence,
                #--- or the legacy confidence echo of a changed decision), or from
                #--- the admission gate (DD05): the ONLY validator result that
                #--- changed is ConfluenceValidator (per-family admission floor),
                #--- and the changed columns are confined to the validator/decision
                #--- echo columns.
                $liq = ($run[$i].hasLiquiditySweep -ne $base[$i].hasLiquiditySweep) -or
                       ($run[$i].ruleName -like "LIQUIDITY_*") -or ($base[$i].ruleName -like "LIQUIDITY_*") -or
                       ($run[$i].ruleEvidenceIds -ne $base[$i].ruleEvidenceIds) -or
                       ($run[$i].legacyConfidence -ne $base[$i].legacyConfidence)
                $admission = $false
                if (-not $liq) {
                    $vb = @{}; $vr = @{}
                    foreach ($p in ($base[$i].validatorResults -split "\|")) { if ($p -match "^([^=]+)=(\d+)") { $vb[$Matches[1]] = $Matches[2] } }
                    foreach ($p in ($run[$i].validatorResults -split "\|")) { if ($p -match "^([^=]+)=(\d+)") { $vr[$Matches[1]] = $Matches[2] } }
                    #--- ConfluenceValidator (the admission gate) must have flipped.
                    $confluenceFlip = $vb.ContainsKey("ConfluenceValidator") -and $vr.ContainsKey("ConfluenceValidator") -and ($vb["ConfluenceValidator"] -ne $vr["ConfluenceValidator"])
                    $consistent = $true
                    foreach ($k in $vb.Keys) {
                        if ($k -eq "ConfluenceValidator") { continue }
                        #--- every shared component must be identical...
                        if (-not $vr.ContainsKey($k) -or $vb[$k] -ne $vr[$k]) { $consistent = $false }
                    }
                    #--- ...and any NEW component appeared only because the pipeline
                    #--- ran past the gate (short-circuit collection on rejection).
                    #--- A hard reject (2) among them must not contradict the
                    #--- recorded verdict: it requires the run decision to be rejected.
                    $hardRejectNew = $false
                    foreach ($k in $vr.Keys) { if (-not $vb.ContainsKey($k) -and $vr[$k] -eq "2") { $hardRejectNew = $true } }
                    $verdictConsistent = (-not $hardRejectNew) -or ($run[$i].newDecision -eq "0")
                    $nonEcho = @($diff | Where-Object { $_ -notin @("validatorResults","newDecision","decisionMatch") }).Count
                    $admission = ($confluenceFlip -and $consistent -and $verdictConsistent -and $nonEcho -eq 0)
                }
                if (-not $liq -and -not $admission) {
                    $attributionBad++
                    if ($attributionBad -le 5) { $detail.Add("decisionId $($run[$i].decisionId) changed without liquidity or admission attribution (rule $($base[$i].ruleName) -> $($run[$i].ruleName))") }
                }
            }
        }
        $missing = @($AllowDecisionIds | Where-Object { -not $changedIds.ContainsKey($_) }).Count
        if ($unexpected -gt 0) { $fail++; $detail.Add("completeness FAIL: $unexpected changed rows outside the allowlist") }
        if ($missing -gt 0) { $fail++; $detail.Add("completeness FAIL: $missing allowlisted decisions did not change") }
        if ($attributionBad -gt 0) { $fail++; $detail.Add("attribution FAIL: $attributionBad allowed decisions not attributable to the liquidity cascade or the admission gate") }
        if ($unexpected -eq 0 -and $missing -eq 0) { $detail.Add("completeness invariant holds: changed rows ($changedTotal) == allowlist ($($AllowDecisionIds.Count))") }
        if ($attributionBad -eq 0) { $detail.Add("attribution invariant holds: all $($AllowDecisionIds.Count) allowed decisions trace to the liquidity cascade or the admission gate") }
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
                if ($script:TT01_SCHEMA_RECORDING -contains $c) { continue }
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
        #--- schema-recording flip check: under the default tier-0.0 profile the
        #--- run CSV is schema v5 (append-only recording) over the frozen v4
        #--- baseline. A clean flip 4 -> 5 on every row is the expected, localized
        #--- recording difference; byte-identity must hold on every other column.
        $schemaFlip = 0
        for ($i = 0; $i -lt $run.Count; $i++) {
            if ($run[$i].schemaVersion -eq "5" -and $base[$i].schemaVersion -eq "4") { $schemaFlip++ }
        }
        if ($schemaFlip -eq $run.Count) {
            $detail.Add("schemaVersion 4 -> 5 on all $($run.Count) rows (Sprint 22 schema recording; gate columns carry OFF sentinels, verified by CONTRACT)")
        } else {
            $fail++
            $detail.Add("schema flip FAIL: $($run.Count - $schemaFlip)/$($run.Count) rows are not v4->v5")
        }
        foreach ($c in $cols) {
            if ($script:TT01_SCHEMA_RECORDING -contains $c) { continue }
            $d = 0
            for ($i = 0; $i -lt $run.Count; $i++) { if ($run[$i].$c -ne $base[$i].$c) { $d++ } }
            if ($d -gt 0) { $diffCols += "$c=$d" }
        }
        if ($diffCols.Count -eq 0) {
            $detail.Add("all $($cols.Count - $script:TT01_SCHEMA_RECORDING.Count) behavior columns byte-identical across $($run.Count) rows")
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

#───────────────────────────────────────────────────────────────────────
#  Sprint 22 (RL-HYP-01): active-tier replay evidence (11.3c/3b).
#  The K1 replay runs the SAME profile with SwingSignificanceTier=1.0.
#  Expected: fewer rows (nGatedOut >= 1), every admitted row records
#  ADMIT with a qualifying pivot id + k*ATR(14) threshold, the fingerprint
#  stays constant and equal to the default run (tier outside canonical),
#  and the admitted decisions (paired by signalTime - the decision bar)
#  are byte-identical to the default run on every shared column
#  (admission-only invariance, gate 3b).
#
#  PAIRING KEY: signalTime, NOT decisionId. decisionId is a sequential
#  collector id assigned in settle/record order; when rows are gated out
#  the admitted rows renumber (e.g. decisionId 1 in the K1 run is the
#  first ADMITTED bar, which may be the default run's decisionId 2). The
#  bar is the stable identity - the analyzer's 0R reconstruction
#  (protocol Amendment A1) must pair on the bar too.
#───────────────────────────────────────────────────────────────────────
function Test-TT01ActiveTier {
    param([string]$RunPath, [string]$BasePath)
    $detail = [System.Collections.Generic.List[string]]::new()
    $fail = 0
    $run = Import-Csv -LiteralPath $RunPath
    $base = Import-Csv -LiteralPath $BasePath
    $nGatedOut = $base.Count - $run.Count

    if ($run.Count -le 0) { $fail++; $detail.Add("active-tier run produced no rows") }
    if ($run.Count -ge $base.Count) {
        $fail++; $detail.Add("admitted $($run.Count) !< default $($base.Count) -> nGatedOut=0 (gate inert, 11.3c FAIL)")
    } else {
        $detail.Add("nGatedOut = $nGatedOut (default $($base.Count) -> admitted $($run.Count))")
    }

    if ($run.Count -gt 0) {
        #--- admission recording: every admitted row must carry ADMIT + evidence
        $admitBad = @($run | Where-Object { $_.gateDecision -ne "ADMIT" }).Count
        if ($admitBad -gt 0) { $fail++; $detail.Add("$admitBad rows with gateDecision != ADMIT") }
        else { $detail.Add("all $($run.Count) admitted rows record gateDecision=ADMIT") }
        $qBad = @($run | Where-Object { [long]($_.swingQualifyingId) -le 0 }).Count
        if ($qBad -gt 0) { $fail++; $detail.Add("$qBad rows with swingQualifyingId <= 0 (ADMIT must reference a pivot)") }
        $aBad = @($run | Where-Object { [double]($_.swingAmplitude) -le 0.0 }).Count
        if ($aBad -gt 0) { $fail++; $detail.Add("$aBad rows with swingAmplitude <= 0 (ADMIT must record k*ATR(14) threshold)") }
        $sBad = @($run | Where-Object { $_.schemaVersion -ne "5" }).Count
        if ($sBad -gt 0) { $fail++; $detail.Add("$sBad rows with schemaVersion != 5") }

        #--- fingerprint invariance: constant and equal to the default run
        $fp = @($run | ForEach-Object { $_.configFingerprint } | Sort-Object -Unique)
        $baseFp = @($base | ForEach-Object { $_.configFingerprint } | Sort-Object -Unique)
        if ($fp.Count -ne 1) { $fail++; $detail.Add("configFingerprint not constant ($($fp.Count) distinct)") }
        elseif ($baseFp.Count -ne 1 -or $fp[0] -ne $baseFp[0]) {
            $fail++; $detail.Add("active-tier fingerprint $($fp[0]) != default $($baseFp -join ',') (tier leaked into the canonical string)")
        } else {
            $detail.Add("fingerprint invariant: $($fp[0]) constant and equal to the default run (tier outside canonical)")
        }

        #--- decision identity: same bars as the default run, unique (gating
        #    is a pure filter; it changes no candidate, it only drops some).
        $runTimes = @($run | ForEach-Object { $_.signalTime } | Sort-Object -Unique)
        $baseTimes = @($base | ForEach-Object { $_.signalTime } | Sort-Object -Unique)
        if ($runTimes.Count -ne $run.Count) { $fail++; $detail.Add("signalTime not unique ($($runTimes.Count) unique vs $($run.Count) rows)") }
        $notInBase = @($run | Where-Object { $baseTimes -notcontains $_.signalTime })
        if ($notInBase.Count -gt 0) { $fail++; $detail.Add("$($notInBase.Count) admitted bars absent from the default run (gate must not invent candidates)") }
        else { $detail.Add("decision identity: all $($run.Count) admitted bars are a subset of the default run's bars (gating is a pure filter)") }

        #--- gate 3b: same-bar rows byte-identical on every non-schema-recording,
        #    non-identity column. decisionId is exempt: it is a sequential
        #    collector id that renumbers when rows are gated out (a recording
        #    difference, like the schema flip - verified above via signalTime).
        $baseByTime = @{}; foreach ($r in $base) { $baseByTime[$r.signalTime] = $r }
        $exempt = @($script:TT01_SCHEMA_RECORDING) + @("decisionId")
        $sharedBad = 0; $sharedBadSample = @()
        foreach ($r in $run) {
            if (-not $baseByTime.ContainsKey($r.signalTime)) { continue }
            foreach ($c in $base[0].PSObject.Properties.Name) {
                if ($exempt -contains $c) { continue }
                if ($r.$c -ne $baseByTime[$r.signalTime].$c) {
                    $sharedBad++
                    if ($sharedBadSample.Count -lt 5) { $sharedBadSample += "bar $($r.signalTime) column $c" }
                }
            }
        }
        if ($sharedBad -gt 0) { $fail++; $detail.Add("gate 3b FAIL: $sharedBad column diffs on admitted bars ($($sharedBadSample -join ' ; '))" ) }
        else { $detail.Add("gate 3b: all $($run.Count) admitted rows byte-identical to the default run on all $($base[0].PSObject.Properties.Name.Count - $exempt.Count) shared columns (signalTime-paired)") }
    }
    New-TT01Result -Name "ACTIVE-TIER" -Pass ($fail -eq 0) -Details $detail.ToArray()
}

#───────────────────────────────────────────────────────────────────────
#  Sprint 22 (RL-HYP-01): SETTLEMENT-ISOLATION + INTEGRITY-CONTROL
#  gates (Design A, docs/Sprint22_RL_HYP_01_Settlement_Isolation_Design
#  .md §8; TDD RED -> GREEN evidence §7).
#
#  Defect under test: SettleDue() is called ONLY inside the gate-ADMIT
#  branch of CSymbolContext::Update (SymbolContext.mqh:975). A queued row
#  whose boundary bar is GATE-OUT is NOT settled on that bar; it defers
#  to the next ADMIT bar, by which time the boundary bar is CLOSED. The
#  horizon exit reads close[boundary bar] (ForwardOutcomeSimulator.mqh
#  :172), so the closed-bar read diverges from the forming-bar read -
#  exactly the 58-row divergence class (all exitReason=4, barsHeld=51).
#
#  The Jan-2026 H1 window used by ACTIVE-TIER never contains a GATE-OUT
#  boundary bar (gate 3b stays green there). The SETTLEMENT-ISOLATION
#  gate replays the DEFECT-FIRING window (EURUSD M15 2026-04-05..
#  07-05, the frozen batch window) as a tiered pair: tier 0.0 (CONTROL)
#  vs tier 1.0. RED on the unfixed build (admitted rows diverge on
#  shared columns), GREEN after Design A (0 divergences).
#
#  Same-bar pairing (signalTime) + exemption set (schema-recording cols
#  + decisionId) mirror the gate 3b / analyzer contract exactly.
#───────────────────────────────────────────────────────────────────────

function Get-TT01ArmRows {
    param([string]$Path)
    $rows = @()
    if (Test-Path -LiteralPath $Path -PathType Container) {
        foreach ($f in @(Get-ChildItem -LiteralPath $Path -Filter "telemetry_v5_*.csv" | Sort-Object Name)) {
            $rows += @(Import-Csv -LiteralPath $f.FullName)
        }
    }
    elseif (Test-Path -LiteralPath $Path) {
        $rows = @(Import-Csv -LiteralPath $Path)
    }
    return $rows
}

function Compare-TT01SameBarGroups {
    #--- shared-column byte-identity of the run arm's rows against the
    #    base arm by signalTime. Exempt set = schema-recording records
    #    (gate cols + schemaVersion) + decisionId (sequential collector
    #    id, renumbers when bars are gated out). Returns failures + a
    #    diagnostic listing of differing columns grouped by bar.
    param([object[]]$Run, [object[]]$Base, [string[]]$Exempt)
    $baseByTime = @{}; foreach ($r in $Base) { $baseByTime[$r.signalTime] = $r }
    $bad = 0; $samples = [System.Collections.Generic.List[string]]::new(); $compared = 0
    foreach ($r in $Run) {
        if (-not $baseByTime.ContainsKey($r.signalTime)) { continue }
        $compared++
        foreach ($c in $Base[0].PSObject.Properties.Name) {
            if ($Exempt -contains $c) { continue }
            if ($r.$c -ne $baseByTime[$r.signalTime].$c) {
                $bad++
                if ($samples.Count -lt 8) { $samples.Add("bar $($r.signalTime) col $c`: $($baseByTime[$r.signalTime].$c) -> $($r.$c)") }
            }
        }
    }
    [pscustomobject]@{ bad = $bad; compared = $compared; samples = @($samples) }
}

function Test-TT01SettlementIsolation {
    param([string]$RunPath, [string]$BasePath)
    $detail = [System.Collections.Generic.List[string]]::new()
    $fail = 0
    $run = @(Get-TT01ArmRows -Path $RunPath)
    $base = @(Get-TT01ArmRows -Path $BasePath)

    if ($run.Count -eq 0 -or $base.Count -eq 0) {
        $fail++; $detail.Add("no rows: run=$($run.Count) base=$($base.Count) (replay unhealthy)")
        New-TT01Result -Name "SETTLEMENT-ISOLATION" -Pass $false -Details $detail.ToArray()
        return
    }
    $nGatedOut = $base.Count - $run.Count
    if ($run.Count -ge $base.Count) {
        $fail++; $detail.Add("admitted $($run.Count) !< default $($base.Count) -> nGatedOut=0 (gate inert in the isolation window, 11.3c FAIL)")
    } else {
        $detail.Add("nGatedOut = $nGatedOut (default $($base.Count) -> admitted $($run.Count))")
    }

    $schemaBad = @($run | Where-Object { $_.schemaVersion -ne "5" }).Count
    if ($schemaBad -gt 0) { $fail++; $detail.Add("$schemaBad isolation-tier rows with schemaVersion != 5") }
    $schemaBadB = @($base | Where-Object { $_.schemaVersion -ne "5" }).Count
    if ($schemaBadB -gt 0) { $fail++; $detail.Add("$schemaBadB isolation-control rows with schemaVersion != 5") }

    $fpRun = @($run | ForEach-Object { $_.configFingerprint } | Sort-Object -Unique)
    $fpBase = @($base | ForEach-Object { $_.configFingerprint } | Sort-Object -Unique)
    if ($fpRun.Count -ne 1) { $fail++; $detail.Add("isolation-tier fingerprint not constant ($($fpRun.Count) distinct)") }
    if ($fpBase.Count -ne 1) { $fail++; $detail.Add("isolation-control fingerprint not constant ($($fpBase.Count) distinct)") }
    if ($fpRun.Count -eq 1 -and $fpBase.Count -eq 1 -and $fpRun[0] -ne $fpBase[0]) {
        $fail++; $detail.Add("isolation-tier fingerprint $($fpRun[0]) != control $($fpBase[0]) (tier leaked into canonical)")
    }
    if ($fail -eq 0 -and $fpRun.Count -eq 1) {
        $detail.Add("fingerprint invariant: $($fpRun[0]) constant and equal across the tiered pair (tier outside canonical)")
    }

    $runTimes = @($run | ForEach-Object { $_.signalTime } | Sort-Object -Unique)
    if ($runTimes.Count -ne $run.Count) { $fail++; $detail.Add("isolation-tier signalTime not unique ($($runTimes.Count) unique vs $($run.Count) rows)") }
    $baseTimes = @($base | ForEach-Object { $_.signalTime } | Sort-Object -Unique)
    $notInBase = @($run | Where-Object { $baseTimes -notcontains $_.signalTime })
    if ($notInBase.Count -gt 0) { $fail++; $detail.Add("$($notInBase.Count) admitted bars absent from the isolation control (gate invented candidates)") }
    else { $detail.Add("decision identity: all admitted bars are a subset of the control bars (gating is a pure filter)") }

    $exempt = @($script:TT01_SCHEMA_RECORDING) + @("decisionId")
    $cmp = Compare-TT01SameBarGroups -Run $run -Base $base -Exempt $exempt
    if ($cmp.bad -gt 0) {
        $fail++
        $detail.Add("gate 3b isolation FAIL: $($cmp.bad) column diffs on $($cmp.compared) admitted rows (Design A RED)")
        foreach ($s in $cmp.samples) { $detail.Add("  $s") }
    } else {
        $detail.Add("gate 3b isolation: all $($cmp.compared) admitted rows byte-identical on all shared non-gate columns (Design A, 58 -> 0)")
    }

    $horizonRun = @($run | Where-Object { $_.exitReason -eq "4" })
    $horizonBase = @($base | Where-Object { $_.exitReason -eq "4" })
    $detail.Add("horizon rows (exitReason=4): control $($horizonBase.Count) vs admitted $($horizonRun.Count) (the deferral-sensitive class, barsHeld=51)")
    $hBad = @($horizonRun | Where-Object { $_.barsHeld -ne "51" }).Count
    if ($hBad -gt 0) { $fail++; $detail.Add("$hBad horizon rows with barsHeld != 51") }
    else { $detail.Add("all horizon rows settle at the max-hold boundary (barsHeld=51)") }

    $admits = @($run | Where-Object { $_.gateDecision -eq "ADMIT" }).Count
    $off = @($run | Where-Object { $_.gateDecision -eq "OFF" }).Count
    $detail.Add("admitted tier-1.0 rows: $admits ADMIT, $off OFF (tier 1.0 must admit only strong pivots)")
    if ($admits -ne $run.Count) { $fail++; $detail.Add("$($run.Count - $admits) admitted rows without gateDecision=ADMIT") }

    New-TT01Result -Name "SETTLEMENT-ISOLATION" -Pass ($fail -eq 0) -Details $detail.ToArray()
}

function Test-TT01IntegrityControl {
    #--- regression control (Design doc §8.3): the fresh tier-0 isolation
    #    arm must be byte-identical to the frozen CONTROL_RLHYP01 batch
    #    artifact (same window/profile): determinism + criterion-6 guard.
    #    Exemption: decisionId only (both records are schema v5).
    param([string]$RunPath, [string]$BasePath)
    $detail = [System.Collections.Generic.List[string]]::new()
    $fail = 0
    $run = @(Get-TT01ArmRows -Path $RunPath)
    $base = @(Get-TT01ArmRows -Path $BasePath)
    if ($run.Count -eq 0) { $fail++; $detail.Add("fresh tier-0 arm has no rows (replay unhealthy)") }
    if ($base.Count -eq 0) { $fail++; $detail.Add("frozen CONTROL artifact has no rows at $BasePath (missing? env error)") }
    if ($fail -gt 0) {
        New-TT01Result -Name "INTEGRITY-CONTROL" -Pass $false -Details $detail.ToArray()
        return
    }
    if ($run.Count -ne $base.Count) {
        $fail++; $detail.Add("row count $($run.Count) != frozen CONTROL $($base.Count) (determinism drift)")
    } else {
        $detail.Add("row count $($run.Count) == frozen CONTROL (determinism holds)")
    }
    $cmp = Compare-TT01SameBarGroups -Run $run -Base $base -Exempt @("decisionId")
    if ($cmp.bad -gt 0) {
        $fail++
        $detail.Add("INTEGRITY byte-identity FAIL: $($cmp.bad) column diffs on $($cmp.compared) rows vs frozen CONTROL")
        foreach ($s in $cmp.samples) { $detail.Add("  $s") }
    } else {
        $detail.Add("INTEGRITY byte-identity: $($cmp.compared)/$($run.Count) rows identical to frozen CONTROL on all shared non-record columns")
    }
    New-TT01Result -Name "INTEGRITY-CONTROL" -Pass ($fail -eq 0) -Details $detail.ToArray()
}
