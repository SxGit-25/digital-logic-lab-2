param([string]$IverilogBin='')
$ErrorActionPreference='Stop'
$root=(Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
if(!$IverilogBin){$IverilogBin=Join-Path $root ((Split-Path $root -Leaf)+'/radar/sim/tools/iverilog/app/bin')}
$stage=Join-Path ([IO.Path]::GetTempPath()) ('radar_budget_regression_'+[guid]::NewGuid().ToString('N'))
$out=Join-Path $root 'radar/unified_scan/results/budget_original_regression.log'
New-Item -ItemType Directory -Force "$stage/radar/rtl","$stage/radar/sim","$stage/radar/verification/baseline/rtl" | Out-Null
Copy-Item "$root/radar/rtl/*.v" "$stage/radar/rtl"
Copy-Item "$root/radar/sim/*.v","$root/radar/sim/run_tests.ps1" "$stage/radar/sim"
Copy-Item "$root/radar/verification/baseline/rtl/*.v" "$stage/radar/verification/baseline/rtl"
& "$stage/radar/sim/run_tests.ps1" -IverilogBin $IverilogBin *> $out
Get-Content $out -Tail 6
if(!(Select-String -LiteralPath $out -Pattern 'PASS all 6 regression suites' -Quiet)){throw 'Original regression did not pass'}
