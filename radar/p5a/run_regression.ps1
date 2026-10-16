param([Parameter(Mandatory=$true)][string]$RunName,[string]$IverilogBin='',
 [string[]]$Suites=@('original','units','measurement','scan','display','matrix','draw','top'),[string]$SourceDir='', [string]$OnlyTest='')
$ErrorActionPreference='Stop'
$root=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
if(!$IverilogBin){$IverilogBin=Join-Path $root '数电实验2/radar/sim/tools/iverilog/app/bin'}
$iv=Join-Path $IverilogBin 'iverilog.exe';$vvp=Join-Path $IverilogBin 'vvp.exe'
if(!(Test-Path $iv)){throw "Icarus not found: $iv"}
$out=Join-Path $PSScriptRoot "runs/$RunName"
if(Test-Path $out){throw "Evidence directory exists; choose a fresh RunName: $out"}
New-Item -ItemType Directory $out | Out-Null
$work=Join-Path ([IO.Path]::GetTempPath()) ('p5_regression_'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory $work | Out-Null
$env:TEMP=$work;$env:TMP=$work
if(!$SourceDir){$SourceDir="$root/radar/rtl"}
Copy-Item "$SourceDir/*.v","$root/radar/sim/lcd/st7565_model.v" $work
$sim=Join-Path $root 'radar/sim/unified_scan'
$statuses=@()
function Run-Test([string]$name,[string]$test,[string[]]$options=@()) {
 if($OnlyTest -and $name -ne $OnlyTest){return}
 $dest=Join-Path $out $name;New-Item -ItemType Directory $dest | Out-Null
 $sources=@(Get-ChildItem "$work/*.v" | ForEach-Object Name)
 & $iv -g2005-sv -Wall -s $test @options -o test.vvp @sources *> "$dest/compile.log"
 if($LASTEXITCODE){throw "$name compilation failed; $dest/compile.log"}
 & $vvp "$work/test.vvp" *> "$dest/simulation.log"
 $code=$LASTEXITCODE;Get-Content "$dest/simulation.log" -Tail 5
 $script:statuses += [pscustomobject]@{Suite=$name;Exit=$code}
 $script:statuses | Export-Csv "$out/status.csv" -NoTypeInformation
 $marker=if($name -eq 'matrix'){'CONFIRMED_BOUND_EXCEEDED'}else{'PASS'}
 if($code -or !(Select-String -LiteralPath "$dest/simulation.log" -Pattern $marker -Quiet)){throw "$name simulation failed; $dest/simulation.log"}
}
try {
 Push-Location $work
 try {
  if($Suites -contains 'original') {
   Copy-Item "$root/radar/sim/tb_*.v" $work
   foreach($name in 'timebase','switch_filter','seg_scan','matrix_scan','ultrasonic','radar_ctrl') {
    $text=[IO.File]::ReadAllText("$root/radar/verification/baseline/rtl/$name.v") -replace "module\s+$name\b","module ${name}_baseline"
    [IO.File]::WriteAllText("$work/${name}_baseline.v",$text,[Text.Encoding]::ASCII)
   }
   foreach($name in 'servo_pwm','ultrasonic','radar_ctrl','radar_top','alarm_ctrl','counter_equivalence'){Run-Test "original_$name" "tb_$name" @('-DBASELINE_COMPARE')}
  }
  foreach($name in 'tb_global_budget','tb_alarm_global','tb_switch_pair','tb_ultrasonic_bcd_budget_compact','tb_display_shared','tb_matrix_latency','tb_budget_top') {Copy-Item "$sim/$name.v" $work}
  $tb="$work/tb_global_budget.v"
  [IO.File]::WriteAllText($tb,([IO.File]::ReadAllText($tb).Replace('radar_global_timebase #','radar_global_timebase_alarm #')),[Text.Encoding]::ASCII)
  if($Suites -contains 'units'){foreach($name in 'tb_global_budget','tb_alarm_global','tb_switch_pair'){Run-Test $name $name}}
  if($Suites -contains 'measurement'){Run-Test 'measurement' 'tb_ultrasonic_bcd_budget_compact'}
  if($Suites -contains 'display'){Run-Test 'display' 'tb_display_shared'}
  if($Suites -contains 'matrix'){Run-Test 'matrix' 'tb_matrix_latency'}
  if($Suites -contains 'scan') {
   Copy-Item "$sim/tb_scan_*.v" $work
   $text=[IO.File]::ReadAllText("$root/radar/unified_scan/results/scan_engine/source/verified_degree1.v").Replace('module radar_unified_scan #','module radar_unified_scan_verified_degree1 #')
   [IO.File]::WriteAllText("$work/radar_unified_scan_verified_degree1.v",$text,[Text.Encoding]::ASCII)
   foreach($name in 'radar_ctrl','servo_pwm') {
    $text=(& git -C $root show "f4507a8:radar/rtl/$name.v") -join "`n"
    if($LASTEXITCODE){throw "Missing legacy reference $name"}
    [IO.File]::WriteAllText("$work/${name}_legacy.v",($text -replace "module $name\b","module ${name}_legacy"),[Text.Encoding]::ASCII)
   }
   Run-Test 'scan_control' 'tb_scan_control'
   Run-Test 'scan_production_basic' 'tb_scan_engine' @('-Ptb_scan_engine.PRODUCTION=1')
   Run-Test 'scan_production_continuous' 'tb_scan_engine' @('-Ptb_scan_engine.PRODUCTION=1','-Ptb_scan_engine.MODE=1')
  }
  if($Suites -contains 'top'){Run-Test 'top' 'tb_budget_top'}
  Get-ChildItem "$work/*.v" | Get-FileHash | Select-Object Hash,@{n='File';e={Split-Path $_.Path -Leaf}} | Export-Csv "$out/sources_sha256.csv" -NoTypeInformation
 } finally {Pop-Location}
 if($Suites -contains 'draw') {
  # Existing direct-draw reference/model remains authoritative and retains its
  # own source hashes and pixel comparisons. A unique run name avoids overwrite.
  & "$sim/run_budget_draw.ps1" -RunName "p5_$RunName" -IverilogBin $IverilogBin -SourceDir $work
  Copy-Item "$root/radar/unified_scan/results/p5_$RunName" "$out/draw" -Recurse
 }
 "PASS selected production regression suites" | Set-Content "$out/PASS.txt"
} finally {Write-Output "Evidence: $out ; isolated sources/work: $work"}
