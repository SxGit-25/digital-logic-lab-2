param([string]$IverilogBin = '')
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
if (!$IverilogBin) { $IverilogBin = Join-Path (Split-Path $root -Parent) 'radar\sim\tools\iverilog\app\bin' }
$iv = Join-Path $IverilogBin 'iverilog.exe'
$vvp = Join-Path $IverilogBin 'vvp.exe'
if (!(Test-Path $iv)) { throw 'Icarus missing; supply -IverilogBin' }
$build = Join-Path $PSScriptRoot 'build'
New-Item -ItemType Directory -Force $build | Out-Null
$log = Join-Path $build 'regression.log'
"Continuous servo sweep regression $(Get-Date -Format o)" | Set-Content -LiteralPath $log
$radarRtl = Join-Path (Split-Path $root -Parent) 'radar\rtl'
$rtl = @((Join-Path $root 'rtl\servo_sweep.v'), (Join-Path $root 'rtl\continuous_scan_top.v'))
foreach ($module in @('reset_ctrl','timebase','switch_filter')) { $rtl += Join-Path $radarRtl "$module.v" }
foreach ($name in @('servo_sweep', 'servo_sweep_params', 'continuous_scan_top')) {
    $out = Join-Path $build "$name.vvp"
    & $iv -g2005-sv -Wall -s "tb_$name" -o $out @rtl (Join-Path $PSScriptRoot "tb_$name.v") 2>&1 | Tee-Object -FilePath $log -Append
    if ($LASTEXITCODE -ne 0) { throw "Compile failed: $name" }
    & $vvp $out 2>&1 | Tee-Object -FilePath $log -Append
    if ($LASTEXITCODE -ne 0) { throw "Simulation failed: $name" }
}
'PASS all 3 continuous sweep suites' | Tee-Object -FilePath $log -Append
