load_package sta
project_open radar_unified_bcd
create_timing_netlist
read_sdc
update_timing_netlist
report_timing -setup -to [get_ports {lcd_rd_n lcd_wr_n lcd_cs_n lcd_a0 lcd_rst_n lcd_data[*]}] -npaths 100 -detail full_path -file lcd_ports.rpt
report_timing -hold -to [get_ports {lcd_rd_n lcd_wr_n lcd_cs_n lcd_a0 lcd_rst_n lcd_data[*]}] -npaths 100 -detail full_path -append -file lcd_ports.rpt
delete_timing_netlist
project_close
