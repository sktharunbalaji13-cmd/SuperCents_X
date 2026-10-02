# TT01 live progress updater — writes dist/assets/tt01-progress.json every 1.5s from gates.jsonl
$ErrorActionPreference = "SilentlyContinue"
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$Dist1 = "C:\Users\k.tharun balaji\.dsh\profiles\node_modules\@deepseek-ai\dsh-web-frontend\dist\assets\tt01-progress.json"
$Dist2 = "C:\Users\k.tharun balaji\AppData\Local\npm-cache\_npx\1e7f6d9597241db0\node_modules\@deepseek-ai\dsh-web-frontend\dist\assets\tt01-progress.json"
$GatesFile = Join-Path $Root "run\gates.jsonl"
$RunId = "TT01_20260904_135657"
try { $m = Get-Content (Join-Path $Root "artifacts\$RunId\manifest.json") -Raw | ConvertFrom-Json; if($m.runId){$RunId=$m.runId} } catch {}
function GetPct($gates) {
  $done = @($gates | Where-Object { $_.pass -eq $true }).Count
  $total = 16
  $pct = [math]::Min(98, [math]::Round(($done / $total) * 100))
  if ($gates | Where-Object { $_.name -eq "REPLAY" -and $_.pass -ne $null }) { $pct = [math]::Max($pct, 42) }
  return $pct
}
while ($true) {
  $gates = @()
  if (Test-Path $GatesFile) {
    $lines = Get-Content $GatesFile -ErrorAction SilentlyContinue
    foreach ($l in $lines) { try { $gates += ($l | ConvertFrom-Json) } catch {} }
  }
  $gateDots = @()
  $phaseLabel = "TT01 — waiting"
  $phase = "COMPILE"
  $pct = 5
  if ($gates.Count -gt 0) {
    $last = $gates[-1]
    $phaseLabel = $last.name
    $termRunning = Get-Process terminal64 -ErrorAction SilentlyContinue
    $metaRunning = Get-Process MetaEditor64 -ErrorAction SilentlyContinue
    if ($termRunning) { $phaseLabel += " — RUNNING" }
    elseif ($metaRunning) { $phaseLabel += " — COMPILING" }
    $pct = GetPct $gates
    if ($gates | Where-Object { $_.name -eq "ACTIVE-TIER" -and $_.pass -ne $null }) { $pct = [math]::Max($pct, 65) }
    if ($termRunning -and ($gates | Where-Object { $_.name -eq "SETTLEMENT-ISOLATION" })) { $pct = 82 }
    $names = @("PREFLIGHT","COMPILE","SUITE","REPLAY","BEHAVIOR","ACTIVE-TIER","SETTLEMENT","INTEGRITY")
    foreach ($n in $names) {
      $g = $gates | Where-Object { $_.name -like "*$n*" } | Select-Object -Last 1
      if ($g) { $gateDots += @{name=$n; pass=$g.pass; running=($g.pass -eq $null)} }
      else { $gateDots += @{name=$n; pass=$null; running=$false} }
    }
    $hasPerf = $gates | Where-Object { $_.name -eq "PERFORMANCE" }
    $anyFail = @($gates | Where-Object { $_.pass -eq $false }).Count -gt 0
    if ($hasPerf -and -not $anyFail -and $gates.Count -ge 12) { $pct = 100; $phaseLabel = "DONE"; $phase = "DONE" }
    elseif ($gates | Where-Object { $_.name -eq "SETTLEMENT-ISOLATION" }) { $phase = "SETTLEMENT" }
    elseif ($gates | Where-Object { $_.name -eq "ACTIVE-TIER" }) { $phase = "ACTIVE-TIER" }
    elseif ($gates | Where-Object { $_.name -eq "REPLAY" }) { $phase = "REPLAY" }
    elseif ($gates | Where-Object { $_.name -eq "SUITE" }) { $phase = "SUITE" }
    else { $phase = "COMPILE" }
  } else {
    $termRunning = Get-Process terminal64 -ErrorAction SilentlyContinue
    $metaRunning = Get-Process MetaEditor64 -ErrorAction SilentlyContinue
    if ($metaRunning) { $phaseLabel = "COMPILE — COMPILING"; $pct = 12; $phase="COMPILE" }
    elseif ($termRunning) { $phaseLabel = "SUITE — RUNNING"; $pct = 28; $phase="SUITE" }
    $gateDots = @(
      @{name="PREFLIGHT";pass=$true;running=$false},
      @{name="COMPILE";pass=$null;running=$true},
      @{name="SUITE";pass=$null;running=$false},
      @{name="REPLAY";pass=$null;running=$false},
      @{name="BEHAVIOR";pass=$null;running=$false},
      @{name="ACTIVE-TIER";pass=$null;running=$false},
      @{name="SETTLEMENT";pass=$null;running=$false},
      @{name="INTEGRITY";pass=$null;running=$false}
    )
  }
  $obj = @{runId=$RunId; pct=$pct; label=$phaseLabel; phase=$phase; gates=$gateDots; ts=(Get-Date -Format "yyyy-MM-ddTHH:mm:ss")}
  $json = $obj | ConvertTo-Json -Compress
  try { Set-Content -Path $Dist1 -Value $json -Encoding UTF8 -NoNewline; Copy-Item $Dist1 $Dist2 -Force -ErrorAction SilentlyContinue } catch {}
  Start-Sleep -Milliseconds 1500
  if ($phase -eq "DONE") { Start-Sleep -Seconds 5; break }
}
