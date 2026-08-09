param([string]$Art = "C:\Users\k.tharun balaji\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Experts\SuperCents_X\Tools\ED01\artifacts")
function Load-Rows($dir) {
    $rows = @()
    foreach ($f in (Get-ChildItem $dir -Filter "telemetry_v4_*.csv")) { $rows += Import-Csv -LiteralPath $f.FullName }
    return $rows
}
foreach ($cfg in @("OB_0.25", "OB_0.30", "OB_0.40", "OB_0.45")) {
    $ctl = Load-Rows "$Art\EURUSD_H1\CONTROL"
    $exp = Load-Rows "$Art\EURUSD_H1\$cfg"
    $diff = 0
    for ($i = 0; $i -lt $ctl.Count; $i++) {
        if ($ctl[$i].newDecision -ne $exp[$i].newDecision -or $ctl[$i].validatorResults -ne $exp[$i].validatorResults) { $diff++ }
    }
    Write-Output "$cfg EURUSD_H1: rows ctl=$($ctl.Count) exp=$($exp.Count) changed=$diff fp=$($exp[0].configFingerprint)"
}
