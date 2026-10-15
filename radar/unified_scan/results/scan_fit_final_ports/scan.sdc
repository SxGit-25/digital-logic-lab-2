create_clock -name clk -period 20 [get_ports clk]
set data_inputs [remove_from_collection [all_inputs] [get_ports clk]]
set_input_delay -clock clk -max 5 $data_inputs
set_input_delay -clock clk -min 0 $data_inputs
set_output_delay -clock clk -max 5 [all_outputs]
set_output_delay -clock clk -min 0 [all_outputs]
