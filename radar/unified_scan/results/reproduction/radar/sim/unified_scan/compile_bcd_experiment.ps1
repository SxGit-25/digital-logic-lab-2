param([string]$QuartusBin='E:\quartus\QuartusII91\quartus\bin64')
$ErrorActionPreference='Stop'
$root=(Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
$results=Join-Path $root 'radar\unified_scan\results\bcd_experiment\quartus'
$stage=Join-Path ([IO.Path]::GetTempPath()) ('radar_bcd_fit_'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force $stage,$results | Out-Null
foreach($name in @('ultrasonic','bin12_to_bcd')) {
 $text=(& git -C $root show "f4507a8:radar/rtl/$name.v") -join "`n"
 if($LASTEXITCODE){throw "Missing immutable baseline $name"}
 $text=$text.Replace("module $name", "module ${name}_bcd_legacy")
 [IO.File]::WriteAllText((Join-Path $stage "${name}_bcd_legacy.v"),$text,[Text.Encoding]::ASCII)
}
Copy-Item (Join-Path $root 'radar\rtl\ultrasonic_bcd_experiment.v'),(Join-Path $root 'radar\rtl\ultrasonic.v') $stage
Copy-Item (Join-Path $PSScriptRoot 'bcd_experiment_variants.v') $stage
$sdc=@'
create_clock -name clk -period 20.000 [get_ports {clk}]
set_false_path -from [get_ports {echo_async}] -to [get_registers {*|echo_meta}]
set_input_delay -clock clk -max 5.000 [get_ports {rst tick_us measure_start cancel}]
set_input_delay -clock clk -min 0.000 [get_ports {rst tick_us measure_start cancel}]
set_output_delay -clock clk -max 5.000 [all_outputs]
set_output_delay -clock clk -min 0.000 [all_outputs]
'@
$status=@()
foreach($variant in @('legacy','optimized','fractional','integer294')) {
 $top="bcd_measurement_$variant";$out=Join-Path $results $variant
 New-Item -ItemType Directory -Force $out | Out-Null
 $qsf=@(
  'set_global_assignment -name FAMILY "MAX II"',
  'set_global_assignment -name DEVICE EPM1270T144C5',
  "set_global_assignment -name TOP_LEVEL_ENTITY $top",
  'set_global_assignment -name ALLOW_POWER_UP_DONT_CARE OFF',
  'set_global_assignment -name USE_TIMEQUEST_TIMING_ANALYZER ON',
  'set_global_assignment -name RESERVE_ALL_UNUSED_PINS "AS INPUT TRI-STATED"',
  'set_global_assignment -name MAXII_OPTIMIZATION_TECHNIQUE AREA',
  'set_global_assignment -name AUTO_RESOURCE_SHARING ON',
  'set_global_assignment -name VERILOG_FILE ultrasonic_bcd_experiment.v',
  'set_global_assignment -name VERILOG_FILE ultrasonic_bcd_legacy.v',
  'set_global_assignment -name VERILOG_FILE bin12_to_bcd_bcd_legacy.v',
  'set_global_assignment -name VERILOG_FILE ultrasonic.v',
  'set_global_assignment -name VERILOG_FILE bcd_experiment_variants.v',
  "set_global_assignment -name SDC_FILE $top.sdc",
  'set_location_assignment PIN_18 -to clk')
 [IO.File]::WriteAllText((Join-Path $stage "$top.qsf"),($qsf -join "`r`n"),[Text.Encoding]::ASCII)
 [IO.File]::WriteAllText((Join-Path $stage "$top.qpf"),"PROJECT_REVISION = $top`r`n",[Text.Encoding]::ASCII)
 [IO.File]::WriteAllText((Join-Path $stage "$top.sdc"),$sdc,[Text.Encoding]::ASCII)
 Push-Location $stage
 try {
  & (Join-Path $QuartusBin 'quartus_sh.exe') --flow compile $top *> "$top.compile.log"
  $code=$LASTEXITCODE
  Get-Content "$top.compile.log" -Tail 5
 } finally {Pop-Location}
 Get-ChildItem -Path "$stage\$top*" -File | Where-Object {$_.Extension -in '.rpt','.summary','.log','.pin','.pof','.qpf','.qsf','.sdc'} | Copy-Item -Destination $out
 $snapshot=Join-Path $out 'source';New-Item -ItemType Directory -Force $snapshot | Out-Null
 Copy-Item "$stage\*.v" $snapshot
 Get-ChildItem -LiteralPath $snapshot -File | Get-FileHash -Algorithm SHA256 | Select-Object Hash,@{n='File';e={Split-Path $_.Path -Leaf}} | Export-Csv -NoTypeInformation (Join-Path $out 'source_sha256.csv')
 $status+=[pscustomobject]@{Variant=$variant;CompileExit=$code}
}
$status | Export-Csv -NoTypeInformation (Join-Path $results 'build_status.csv')
Write-Output "Standalone measurement-block evidence retained in $results; stage=$stage"
if($status.CompileExit | Where-Object {$_ -ne 0}){throw 'One or more standalone BCD experiment builds failed'}
