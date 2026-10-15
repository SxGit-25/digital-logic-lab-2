param([string]$IverilogBin='')
$ErrorActionPreference='Stop'
$root=(Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
if(!$IverilogBin){$IverilogBin=Join-Path $root ((Split-Path $root -Leaf)+'/radar/sim/tools/iverilog/app/bin')}
$stage=Join-Path ([IO.Path]::GetTempPath()) ('radar_budget_units_'+[guid]::NewGuid().ToString('N'))
$out=Join-Path $root 'radar/unified_scan/results/budget_units'
New-Item -ItemType Directory -Force $stage,$out | Out-Null
Copy-Item "$root/radar/rtl/*.v","$PSScriptRoot/tb_global_budget.v","$PSScriptRoot/tb_alarm_global.v","$PSScriptRoot/tb_switch_pair.v" $stage
$tb=Join-Path $stage 'tb_global_budget.v'
[IO.File]::WriteAllText($tb,([IO.File]::ReadAllText($tb).Replace('radar_global_timebase #','radar_global_timebase_alarm #')),[Text.Encoding]::ASCII)
Push-Location $stage
try{
 foreach($name in 'tb_global_budget','tb_alarm_global','tb_switch_pair'){
  & "$IverilogBin/iverilog.exe" -g2005-sv -s $name -o test.vvp *.v *> "$out/$name.compile.log"
  if($LASTEXITCODE){throw "compile $name failed"}
  & "$IverilogBin/vvp.exe" test.vvp *> "$out/$name.simulation.log"
  Get-Content "$out/$name.simulation.log"
  if($LASTEXITCODE){throw "simulation $name failed"}
 }
 Get-ChildItem *.v | Get-FileHash | Select-Object Hash,@{n='File';e={Split-Path $_.Path -Leaf}} | Export-Csv "$out/source_sha256.csv" -NoTypeInformation
 Copy-Item tb_*.v $out
}finally{Pop-Location}
