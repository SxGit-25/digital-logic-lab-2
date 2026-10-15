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

# UFM external serial clocks: phase counter never resets on a transaction;
# pulses rise at phase=0 and fall at phase=16 (period 32 main clocks).
create_generated_clock -name ufm_arclk -source [get_ports clk] -divide_by 32 [get_registers {*|g_ufm.arclk}]
create_generated_clock -name ufm_drclk -source [get_ports clk] -divide_by 32 [get_registers {*|g_ufm.drclk}]
# DRDOUT is captured only at phase=31, 620 ns after its launching DRCLK edge.
# Limit the exception to UFM serial output -> the nine-bit lookup value register.
set_multicycle_path -setup -end 31 -from [get_clocks ufm_drclk] -to [get_registers {*|lcd_sin_lut:lut|value[*]}]
set_multicycle_path -hold -end 30 -from [get_clocks ufm_drclk] -to [get_registers {*|lcd_sin_lut:lut|value[*]}]

# ARDIN and DRSHFT change only at phase=16, halfway between serial rises.
# Last possible launch is 16 main clocks before capture; next change is 16
# clocks after capture. Shift source setup to that launch and source hold to
# the next enabled launch (not the unenabled 50 MHz edges).
set_multicycle_path -setup -start 16 -from [get_registers {*|g_ufm.addr_shift[8]}] -to [get_registers {*OBSERVABLEADDRESSREGOUT}]
set_multicycle_path -hold -start 31 -from [get_registers {*|g_ufm.addr_shift[8]}] -to [get_registers {*OBSERVABLEADDRESSREGOUT}]
set_multicycle_path -setup -start 16 -from [get_registers {*|g_ufm.drshft}] -to [get_registers {*|ufm_drdout}]
set_multicycle_path -hold -start 31 -from [get_registers {*|g_ufm.drshft}] -to [get_registers {*|ufm_drdout}]
