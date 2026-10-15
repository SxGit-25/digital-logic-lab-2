create_clock -name clk -period 20.000 [get_ports {clk}]
# 5 ns external routing/load allowance. Protocol checks are in README.md;
# this is not a 50 MHz LCD sampling-clock specification.
set_output_delay -clock clk -max 5.000 [get_ports {lcd_* led[*]}]
set_output_delay -clock clk -min 0.000 [get_ports {lcd_* led[*]}]
