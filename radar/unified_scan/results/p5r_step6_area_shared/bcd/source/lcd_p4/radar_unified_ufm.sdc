# Fixed-phase gated clocks: /16, high and low each 8 main-clock periods.
create_generated_clock -name ufm_arclk -source [get_ports {clk}] -divide_by 16 [get_registers {*|arclk}]
create_generated_clock -name ufm_drclk -source [get_ports {clk}] -divide_by 16 [get_registers {*|drclk}]
# Serial output is sampled at phase15, 300 ns after the registered DRCLK rise.
set_multicycle_path -setup -end 15 -from [get_registers {*ufm_drdout}] -to [get_registers {*|value[*]}]
set_multicycle_path -hold -end 14 -from [get_registers {*ufm_drdout}] -to [get_registers {*|value[*]}]
# DRSHFT changes only at phase8: 160 ns before/after the next load edge.
set_multicycle_path -setup -start 8 -from [get_registers {*|drshft}] -to [get_registers {*ufm_drdout}]
set_multicycle_path -hold -start 15 -from [get_registers {*|drshft}] -to [get_registers {*ufm_drdout}]
# Address load occurs at request acceptance; ALIGN guarantees >=2 main clocks
# before its first ARCLK rise. Later bits change only at phase8, 160 ns after
# the preceding rise. These two endpoint-specific exceptions therefore model
# >=40 ns setup and >=160 ns hold, instead of a fictitious same-edge update.
# With -start: setup2 gives 40 ns; hold9 restores a +160 ns launch relation.
set_multicycle_path -setup -start 2 -from [get_registers {*|value[15] *|arshft}] -to [get_registers {*OBSERVABLEADDRESSREGOUT}]
set_multicycle_path -hold -start 9 -from [get_registers {*|value[15] *|arshft}] -to [get_registers {*OBSERVABLEADDRESSREGOUT}]
