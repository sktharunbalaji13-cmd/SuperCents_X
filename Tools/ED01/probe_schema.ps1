param([string]$Dir = "C:\Users\k.tharun balaji\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Experts\SuperCents_X\Tools\ED01\artifacts\EURUSD_H1\CONTROL")
$rows = @()
foreach ($f in (Get-ChildItem $Dir -Filter "*.csv")) { $rows += Import-Csv -LiteralPath $f.FullName }
Write-Output "total rows: $($rows.Count)"
Write-Output "distinct decisionId: $(($rows.decisionId | Sort-Object -Unique).Count)"
$o = @($rows | Where-Object { $_.outcome -ne '0' })
Write-Output "rows outcome!=0: $($o.Count)"
Write-Output "  of those newDecision=1: $(@($o | Where-Object { $_.newDecision -eq '1' }).Count)"
Write-Output "  of those newDecision=0: $(@($o | Where-Object { $_.newDecision -eq '0' }).Count)"
Write-Output "exitReason values: $(($rows.exitReason | Sort-Object -Unique) -join ',')"
Write-Output "=== sample: outcome!=0 & newDecision=0 ==="
@($o | Where-Object { $_.newDecision -eq '0' }) | Select-Object -First 3 | ForEach-Object {
    Write-Output ("dec={0} ts={1} nd={2} o={3} r={4} exit={5} vm={6}" -f $_.decisionId, $_.timestamp, $_.newDecision, $_.outcome, $_.rMultiple, $_.exitReason, $_.validatorResults) }
Write-Output "=== sample: outcome!=0 & newDecision=1 ==="
@($o | Where-Object { $_.newDecision -eq '1' }) | Select-Object -First 3 | ForEach-Object {
    Write-Output ("dec={0} ts={1} o={2} r={3} exit={4}" -f $_.decisionId, $_.timestamp, $_.outcome, $_.rMultiple, $_.exitReason) }
Write-Output "=== validatorResults sample values ==="
($rows.validatorResults | Sort-Object -Unique | Select-Object -First 12) -join " | "
Write-Output "=== newDecision=1 with outcome=0 count ==="
Write-Output "$(@($rows | Where-Object { $_.newDecision -eq '1' -and $_.outcome -eq '0' }).Count)"
Write-Output "=== outcome=0 with newDecision=0 count ==="
Write-Output "$(@($rows | Where-Object { $_.newDecision -eq '0' -and $_.outcome -eq '0' }).Count)"
