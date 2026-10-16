load_package sta
project_open radar_unified_bcd
create_timing_netlist
read_sdc
update_timing_netlist
report_ucp -file p5a0_unconstrained.rpt
report_timing -setup -to [get_ports {lcd_*}] -npaths 100 -detail full_path -file p5a0_lcd_ports.rpt
report_timing -hold -to [get_ports {lcd_*}] -npaths 100 -detail full_path -append -file p5a0_lcd_ports.rpt
delete_timing_netlist
project_close
