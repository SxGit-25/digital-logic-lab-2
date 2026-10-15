# This 20 ns period matches CLK_HZ=50_000_000 in radar_mode_top.v.
# Before compiling for hardware, select the board clock and update both values.
create_clock -name clk -period 20.000 [get_ports {clk}]

# Only the first stage of each explicit two-flop synchronizer is asynchronous.
set_false_path -from [get_ports {sw7}] -to [get_registers {*|sw_meta[0]}]
set_false_path -from [get_ports {echo}] -to [get_registers {*|echo_meta}]

set_false_path -from [get_ports {sw6}] -to [get_registers {*|sw_meta[1]}]

# 5 ns external routing/load allowance. Protocol checks are in README.md;
# this is not a 50 MHz LCD sampling-clock specification.
set_output_delay -clock clk -max 5.000 [get_ports {lcd_*}]
set_output_delay -clock clk -min 0.000 [get_ports {lcd_*}]
# RD assertion to sample = 180 ns (9 clocks). Reserve 110 ns externally:
# 14 ns clock-to-RD allowance + 70 ns access * 1.3 + 5 ns board skew.
# Fitted RD Tco must remain <=14 ns; capture registers only.
set_input_delay -clock clk -max 110.000 [get_ports {lcd_data[*]}]
set_input_delay -clock clk -min 0.000 [get_ports {lcd_data[*]}]
set_multicycle_path -setup -end 9 -from [get_ports {lcd_data[*]}] -to [get_registers {*|read_data[*]}]
set_multicycle_path -hold -end 8 -from [get_ports {lcd_data[*]}] -to [get_registers {*|read_data[*]}]
