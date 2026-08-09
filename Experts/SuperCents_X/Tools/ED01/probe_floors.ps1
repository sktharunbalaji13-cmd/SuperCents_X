param([string]$Art = "C:\Users\k.tharun balaji\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Experts\SuperCents_X\Tools\ED01\artifacts")
function Load-Rows($dir) {
    $rows = @()
    foreach ($f in (Get-ChildItem $dir -Filter "telemetry_v4_*.csv")) { $rows += Import-Csv -LiteralPath $f.FullName }
    return $rows
}
foreach ($pair in @(@("CONTROL", "LIQUIDITY_0.65"), @("CONTROL", "FVG_0.45"), @("CONTROL", "BOS_0.45"))) {
    $ctl = Load-Rows "$Art\EURUSD_H1\$($pair[0])"
    $exp = Load-Rows "$Art\EURUSD_H1\$($pair[1])"
    Write-Output "=== $($pair[1]) vs $($pair[0]) EURUSD_H1 ==="
    Write-Output "total rows ctl=$($ctl.Count) exp=$($exp.Count)"
    Write-Output "newDecision=1 ctl=$(@($ctl | Where-Object { $_.newDecision -eq '1' }).Count) exp=$(@($exp | Where-Object { $_.newDecision -eq '1' }).Count)"
    $q = @($ctl | Where-Object { $_.newDecision -eq '1' })
    $raw = @($q | Where-Object { $_.ruleName -match 'LIQUIDITY|FVG|BOS' } | ForEach-Object { [pscustomobject]@{ rule=$_.ruleName; raw=$_.liquidityRaw + ',' + $_.fvgRaw + ',' + $_.obRaw } })
    Write-Output "--- ctl qualified sample raw scores (liquidityRaw,fvgRaw,obRaw) by rule ---"
    $q | Where-Object { $_.ruleName -match 'LIQUIDITY|FVG|BOS' } | Select-Object -First 5 | ForEach-Object { Write-Output ("rule={0} liq={1} fvg={2} ob={3} conf={4}" -f $_.ruleName, $_.liquidityRaw, $_.fvgRaw, $_.obRaw, $_.newConfidence) }
    Write-Output "--- exp($($pair[1])) qualified family counts ---"
    $q2 = @($exp | Where-Object { $_.newDecision -eq '1' })
    ($q2.ruleName | Group-Object | ForEach-Object { Write-Output "$($_.Name): $($_.Count)" })
}
