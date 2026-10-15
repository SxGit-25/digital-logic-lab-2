# This 20 ns period matches CLK_HZ=50_000_000 in radar_mode_top.v.
# Before compiling for hardware, select the board clock and update both values.
create_clock -name clk -period 20.000 [get_ports {clk}]

# Only the first stage of each explicit two-flop synchronizer is asynchronous.
set_false_path -from [get_ports {sw7}] -to [get_registers {*|sw_meta}]
set_false_path -from [get_ports {echo}] -to [get_registers {*|echo_meta}]

set_false_path -from [get_ports {sw6}] -to [get_registers {*|sw_meta}]

# 5 ns external routing/load allowance. Protocol checks are in README.md;
# this is not a 50 MHz LCD sampling-clock specification.
set_output_delay -clock clk -max 5.000 [get_ports {lcd_*}]
set_output_delay -clock clk -min 0.000 [get_ports {lcd_*}]
