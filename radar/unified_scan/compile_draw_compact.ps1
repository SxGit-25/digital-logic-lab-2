param([string]$QuartusBin='E:\quartus\QuartusII91\quartus\bin64',[string]$RunName='draw_compact15')
$ErrorActionPreference='Stop'
$radar=Split-Path $PSScriptRoot -Parent
$stage=Join-Path ([IO.Path]::GetTempPath()) ('radar_minsky_'+[guid]::NewGuid().ToString('N'))
$out=Join-Path $PSScriptRoot "results/$RunName"
New-Item -ItemType Directory -Force $stage,$out | Out-Null
foreach($name in 'lcd_bus','lcd_init','radar_minsky_draw_compact','minsky_serial_datapath') {Copy-Item "$radar/rtl/$name.v" $stage}
Copy-Item "$PSScriptRoot/minsky_lcd_compact_test_top.v" $stage
$qsf=@('set_global_assignment -name FAMILY "MAX II"','set_global_assignment -name DEVICE EPM1270T144C5',
 'set_global_assignment -name TOP_LEVEL_ENTITY minsky_lcd_compact_test_top','set_global_assignment -name ALLOW_POWER_UP_DONT_CARE OFF',
 'set_global_assignment -name USE_TIMEQUEST_TIMING_ANALYZER ON','set_global_assignment -name MAXII_OPTIMIZATION_TECHNIQUE AREA',
 'set_global_assignment -name AUTO_RESOURCE_SHARING ON','set_global_assignment -name MUX_RESTRUCTURE ON',
 'set_location_assignment PIN_18 -to clk')
Get-ChildItem "$stage/*.v" | ForEach-Object {$qsf+='set_global_assignment -name VERILOG_FILE '+$_.Name}
foreach($name in 'rst','delay_tick','request','direction_up','radius_valid','angle_bcd[*]','radius[*]','ready','done','dropped[*]'){
 $qsf+='set_instance_assignment -name VIRTUAL_PIN ON -to '+$name
}
$pins=@{'lcd_rd_n'=32;'lcd_wr_n'=37;'lcd_a0'=48;'lcd_rst_n'=109;'lcd_cs_n'=108;'lcd_data[7]'=107;'lcd_data[6]'=106;'lcd_data[5]'=105;'lcd_data[4]'=104;'lcd_data[3]'=103;'lcd_data[2]'=102;'lcd_data[1]'=110;'lcd_data[0]'=101}
foreach($name in $pins.Keys){$qsf+="set_location_assignment PIN_$($pins[$name]) -to $name";$qsf+='set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to '+$name}
$qsf+='set_global_assignment -name SDC_FILE minsky.sdc'
[IO.File]::WriteAllLines("$stage/minsky.qsf",$qsf,[Text.Encoding]::ASCII)
[IO.File]::WriteAllText("$stage/minsky.qpf",'PROJECT_REVISION = "minsky"',[Text.Encoding]::ASCII)
$sdc=@('create_clock -name clk -period 20 [get_ports clk]',
 'set_input_delay -clock clk -max 0 [get_ports {rst delay_tick request direction_up radius_valid angle_bcd[*] radius[*]}]',
 'set_input_delay -clock clk -min 0 [get_ports {rst delay_tick request direction_up radius_valid angle_bcd[*] radius[*]}]',
 'set_output_delay -clock clk -max 5 [get_ports {lcd_* ready done dropped[*]}]',
 'set_output_delay -clock clk -min 0 [get_ports {lcd_* ready done dropped[*]}]',
 'set_input_delay -clock clk -max 110 [get_ports {lcd_data[*]}]',
 'set_input_delay -clock clk -min 0 [get_ports {lcd_data[*]}]',
 'set_multicycle_path -setup -end 9 -from [get_ports {lcd_data[*]}] -to [get_registers {*|read_data[*]}]',
 'set_multicycle_path -hold -end 8 -from [get_ports {lcd_data[*]}] -to [get_registers {*|read_data[*]}]')
[IO.File]::WriteAllLines("$stage/minsky.sdc",$sdc,[Text.Encoding]::ASCII)
Push-Location $stage
try{
 & "$QuartusBin/quartus_sh.exe" --flow compile minsky *> "$stage/minsky.compile.log"
 $code=$LASTEXITCODE
 Get-Content "$stage/minsky.compile.log" -Tail 8
 Get-ChildItem "$stage/minsky*" -File | Where-Object {$_.Extension -in '.rpt','.summary','.log','.qsf','.qpf','.sdc','.pin','.pof'} | Copy-Item -Destination $out
 New-Item -ItemType Directory -Force "$out/source" | Out-Null
 Copy-Item "$stage/*.v","$stage/minsky.qsf","$stage/minsky.qpf","$stage/minsky.sdc" "$out/source"
 Get-ChildItem "$out/source" -File | ForEach-Object {[PSCustomObject]@{File=$_.Name;SHA256=(Get-FileHash $_.FullName).Hash}} | Export-Csv "$out/source_sha256.csv" -NoTypeInformation
 if($code){throw "Draw component compile failed code=$code"}
}finally{Pop-Location}
