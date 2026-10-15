# Run with quartus_sta -t timing_details.tcl <project> after full compilation.
load_package sta
set project [lindex $quartus(args) 0]
project_open $project
create_timing_netlist
read_sdc
update_timing_netlist
set out "${project}.timing_details.rpt"
report_timing -setup -npaths 5 -detail full_path -file $out
report_timing -hold -npaths 5 -detail full_path -append -file $out
if {![string match *safe $project]} {
    set lcd_capture [get_registers {*|read_data[*]}]
    puts "LCD capture registers: [get_collection_size $lcd_capture]"
    report_timing -setup -from [get_ports {lcd_data[*]}] -to $lcd_capture -npaths 8 -detail full_path -append -file $out
    report_timing -hold -from [get_ports {lcd_data[*]}] -to $lcd_capture -npaths 8 -detail full_path -append -file $out
}
if {[string match *ufm $project]} {
    set values [get_registers {*|lcd_sin_lut:lut|value[*]}]
    set serial [get_registers {*|ufm_drdout}]
    set addr [get_registers {*OBSERVABLEADDRESSREGOUT}]
    puts "UFM capture registers: [get_collection_size $values]; serial: [get_collection_size $serial]; address: [get_collection_size $addr]"
    report_timing -setup -from $serial -to $values -npaths 1 -detail full_path -append -file $out
    report_timing -hold -from $serial -to $values -npaths 1 -detail full_path -append -file $out
    report_timing -setup -from [get_registers {*|g_ufm.addr_shift[8]}] -to $addr -npaths 1 -detail full_path -append -file $out
    report_timing -hold -from [get_registers {*|g_ufm.addr_shift[8]}] -to $addr -npaths 1 -detail full_path -append -file $out
    report_timing -setup -from [get_registers {*|g_ufm.drshft}] -to $serial -npaths 1 -detail full_path -append -file $out
    report_timing -hold -from [get_registers {*|g_ufm.drshft}] -to $serial -npaths 1 -detail full_path -append -file $out
}
delete_timing_netlist
project_close
