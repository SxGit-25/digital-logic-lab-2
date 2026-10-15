`timescale 1ns/1ps
`define BCD_PINS input wire clk,rst,tick_us,measure_start,cancel,echo_async,output wire trig,measure_busy,measure_done,output wire [15:0] distance_bcd,output wire distance_valid,output wire [2:0] distance_level,output wire [5:0] radius,output wire radius_valid
`define BCD_CONNECTION clk,rst,tick_us,measure_start,cancel,echo_async,trig,measure_busy,measure_done,distance_bcd,distance_valid,distance_level,radius,radius_valid
module bcd_measurement_fractional(`BCD_PINS);
 ultrasonic_bcd_experiment #(.DIVIDER_MODE(0)) measurement(`BCD_CONNECTION);
endmodule
module bcd_measurement_integer294(`BCD_PINS);
 ultrasonic_bcd_experiment #(.DIVIDER_MODE(1)) measurement(`BCD_CONNECTION);
endmodule
module bcd_measurement_legacy(`BCD_PINS);
 wire [11:0] mm;
 ultrasonic_bcd_legacy #(.ENABLE_RADIUS(1)) measurement(
  clk,rst,tick_us,measure_start,cancel,echo_async,trig,measure_busy,measure_done,mm,distance_valid,radius,radius_valid);
 bin12_to_bcd_bcd_legacy converter(clk,rst,mm,distance_bcd);
 assign distance_level=!distance_valid?0:mm>=800?1:mm>=600?2:mm>=400?3:mm>=200?4:5;
endmodule
module bcd_measurement_optimized(`BCD_PINS);
 wire [11:0] mm;
 ultrasonic #(.ENABLE_RADIUS(1)) measurement(
  clk,rst,tick_us,measure_start,cancel,echo_async,trig,measure_busy,measure_done,mm,distance_valid,radius,radius_valid);
 bin12_to_bcd_bcd_legacy converter(clk,rst,mm,distance_bcd);
 assign distance_level=!distance_valid?0:mm>=800?1:mm>=600?2:mm>=400?3:mm>=200?4:5;
endmodule
