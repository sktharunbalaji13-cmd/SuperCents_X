param([string]$Art = "C:\Users\k.tharun balaji\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Experts\SuperCents_X\Tools\ED01\artifacts")
function Load-Rows($dir) {
    $rows = @()
    foreach ($f in (Get-ChildItem $dir -Filter "telemetry_v4_*.csv")) { $rows += Import-Csv -LiteralPath $f.FullName }
    return $rows
}
Write-Output "=== fingerprints per config (EURUSD_H1) ==="
Get-ChildItem "$Art\EURUSD_H1" -Directory | ForEach-Object {
    $rows = Load-Rows $_.FullName
    $fp = ($rows | Select-Object -First 1).configFingerprint
    Write-Output ("{0,-16} fp={1}" -f $_.Name, $fp) }
Write-Output ""
Write-Output "=== distinct newConfidence per rule (CONTROL EURUSD_H1, qualified) ==="
$ctl = Load-Rows "$Art\EURUSD_H1\CONTROL"
$q = @($ctl | Where-Object { $_.newDecision -eq '1' })
$q | Group-Object ruleName | ForEach-Object {
    $confs = ($_.Group.newConfidence | Sort-Object -Unique) -join ','
    Write-Output ("{0,-28} n={1,-4} conf=[{2}]" -f $_.Name, $_.Count, $confs) }
Write-Output ""
Write-Output "=== distinct structureRaw/liquidityRaw among qualified LIQUIDITY rows ==="
$q | Where-Object { $_.ruleName -like 'LIQUIDITY*' } | Group-Object liquidityRaw | ForEach-Object {
    Write-Output ("liquidityRaw={0,-4} n={1}" -f $_.Name, $_.Count) }
$q | Where-Object { $_.ruleName -like 'BOS*' } | Group-Object structureRaw | ForEach-Object {
    Write-Output ("BOS structureRaw={0,-4} n={1}" -f $_.Name, $_.Count) }
