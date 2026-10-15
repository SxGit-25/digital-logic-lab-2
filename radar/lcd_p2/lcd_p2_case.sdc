create_clock -name clk -period 20.000 [get_ports {clk}]
# 5 ns external routing/load allowance. Protocol checks are in README.md;
# this is not a 50 MHz LCD sampling-clock specification.
set_output_delay -clock clk -max 5.000 [get_ports {lcd_* led[*]}]
set_output_delay -clock clk -min 0.000 [get_ports {lcd_* led[*]}]
# RD assertion to sample = 180 ns (9 clocks). Reserve 110 ns externally:
# 14 ns clock-to-RD allowance + 70 ns access * 1.3 + 5 ns board skew.
# Fitted RD Tco must remain <=14 ns; capture registers only.
set_input_delay -clock clk -max 110.000 [get_ports {lcd_data[*]}]
set_input_delay -clock clk -min 0.000 [get_ports {lcd_data[*]}]
set_multicycle_path -setup -end 9 -from [get_ports {lcd_data[*]}] -to [get_registers {*|read_data[*]}]
set_multicycle_path -hold -end 8 -from [get_ports {lcd_data[*]}] -to [get_registers {*|read_data[*]}]
