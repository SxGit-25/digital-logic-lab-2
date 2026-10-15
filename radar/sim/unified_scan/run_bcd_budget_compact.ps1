param([switch]$Quartus)
$ErrorActionPreference='Stop'
$root=(Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
$out=Join-Path $root 'radar\unified_scan\results\bcd_budget_compact'
$stage=Join-Path ([IO.Path]::GetTempPath()) ('radar_bcd_budget_compact_'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force $out,$stage | Out-Null
Copy-Item (Join-Path $root 'radar\rtl\ultrasonic_bcd_budget_compact.v'),(Join-Path $PSScriptRoot 'tb_ultrasonic_bcd_budget_compact.v') $stage
$iverilog=Join-Path $root ((Split-Path $root -Leaf)+'\radar\sim\tools\iverilog\app\bin')
Push-Location $stage
try {
 & "$iverilog\iverilog.exe" -g2005-sv -s tb_ultrasonic_bcd_budget_compact -o budget.vvp ultrasonic_bcd_budget_compact.v tb_ultrasonic_bcd_budget_compact.v *> compile.log
 if($LASTEXITCODE){throw 'Icarus compilation failed'}
 & "$iverilog\vvp.exe" budget.vvp *> simulation.log
 if($LASTEXITCODE){Get-Content simulation.log;throw 'Budget measurement simulation failed'}
 Get-Content simulation.log
 if($Quartus){
 @'
set_global_assignment -name FAMILY "MAX II"
set_global_assignment -name DEVICE EPM1270T144C5
set_global_assignment -name TOP_LEVEL_ENTITY ultrasonic_bcd_budget_compact
set_global_assignment -name VERILOG_FILE ultrasonic_bcd_budget_compact.v
set_global_assignment -name MAXII_OPTIMIZATION_TECHNIQUE AREA
set_global_assignment -name AUTO_RESOURCE_SHARING ON
set_global_assignment -name USE_TIMEQUEST_TIMING_ANALYZER ON
set_global_assignment -name SDC_FILE budget.sdc
set_location_assignment PIN_18 -to clk
'@ | Set-Content budget.qsf
 'PROJECT_REVISION = budget' | Set-Content budget.qpf
 @'
create_clock -name clk -period 20.000 [get_ports clk]
set_false_path -from [get_ports echo_async] -to [get_registers {*|echo_meta}]
set_input_delay -clock clk -max 5.000 [get_ports {rst tick_us tick_ms measure_start cancel}]
set_input_delay -clock clk -min 0.000 [get_ports {rst tick_us tick_ms measure_start cancel}]
set_output_delay -clock clk -max 5.000 [all_outputs]
set_output_delay -clock clk -min 0.000 [all_outputs]
'@ | Set-Content budget.sdc
 & 'E:\quartus\QuartusII91\quartus\bin64\quartus_sh.exe' --flow compile budget *> budget.compile.log
 if($LASTEXITCODE){throw 'Standalone Quartus compilation failed'}
 Get-Content budget.fit.summary
 }
} finally {
 Get-ChildItem -File | Where-Object {$_.Extension -in '.log','.rpt','.summary','.qsf','.qpf','.sdc','.v'} | Copy-Item -Destination $out
 Pop-Location
}
