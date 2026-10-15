param([string]$QuartusBin='E:\quartus\QuartusII91\quartus\bin64',[string]$RunName='scan_fit2')
$ErrorActionPreference='Stop'
$radar=Split-Path $PSScriptRoot -Parent
$stage=Join-Path ([IO.Path]::GetTempPath()) ('scan_fit_'+[guid]::NewGuid().ToString('N'))
$out=Join-Path $PSScriptRoot "results/$RunName"
New-Item -ItemType Directory -Force $stage,$out | Out-Null
Copy-Item "$radar/rtl/radar_unified_scan.v" $stage
$qsf=@('set_global_assignment -name FAMILY "MAX II"','set_global_assignment -name DEVICE EPM1270T144C5',
 'set_global_assignment -name TOP_LEVEL_ENTITY radar_unified_scan',
 'set_global_assignment -name VERILOG_FILE radar_unified_scan.v',
 'set_global_assignment -name ALLOW_POWER_UP_DONT_CARE OFF',
 'set_global_assignment -name USE_TIMEQUEST_TIMING_ANALYZER ON',
 'set_global_assignment -name MAXII_OPTIMIZATION_TECHNIQUE AREA',
 'set_global_assignment -name AUTO_RESOURCE_SHARING ON','set_global_assignment -name MUX_RESTRUCTURE ON',
 'set_location_assignment PIN_18 -to clk','set_global_assignment -name SDC_FILE scan.sdc')

foreach($port in @('rst','tick_us','tick_ms','enable','continuous_mode','measure_busy','measure_done','distance_mm','distance_valid','system_state','servo','servo_enable','angle_bcd','direction_up','measure_start','measure_cancel','sample_angle_bcd','sample_direction_up','sample_idx','current_distance','current_valid','current_level','hist_level0','hist_level1','hist_level2','hist_level3','hist_level4','hist_valid','hist_seen','step_event','sample_event','frame_start','fast_busy','distance_bcd','current_bcd','measurement_pending')){ $qsf+='set_instance_assignment -name VIRTUAL_PIN ON -to '+$port }
[IO.File]::WriteAllLines("$stage/scan.qsf",$qsf,[Text.Encoding]::ASCII)
[IO.File]::WriteAllText("$stage/scan.qpf",'PROJECT_REVISION = "scan"',[Text.Encoding]::ASCII)
$sdc=@('create_clock -name clk -period 20 [get_ports clk]',
 'set data_inputs [remove_from_collection [all_inputs] [get_ports clk]]',
 'set_input_delay -clock clk -max 5 $data_inputs','set_input_delay -clock clk -min 0 $data_inputs',
 'set_output_delay -clock clk -max 5 [all_outputs]','set_output_delay -clock clk -min 0 [all_outputs]')
[IO.File]::WriteAllLines("$stage/scan.sdc",$sdc,[Text.Encoding]::ASCII)
Push-Location $stage
try{
 & "$QuartusBin/quartus_sh.exe" --flow compile scan *> "$stage/scan.compile.log"
 $code=$LASTEXITCODE
 Get-Content "$stage/scan.compile.log" -Tail 8
 Get-ChildItem "$stage/scan*" -File | Where-Object {$_.Extension -in '.rpt','.summary','.log','.qsf','.qpf','.sdc','.pin','.pof'} | Copy-Item -Destination $out
 Copy-Item "$stage/radar_unified_scan.v" $out
 if($code){throw "Scan compile failed code=$code"}
}finally{Pop-Location}
