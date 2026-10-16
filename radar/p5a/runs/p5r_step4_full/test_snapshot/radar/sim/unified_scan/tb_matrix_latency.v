`timescale 1ns/1ps
// Counterexample: identical new/old history data arrives 20ms apart, while
// the unchanged multiplexed matrix can expose it more than 20ms apart.
module tb_matrix_latency;
 reg clk=0,rst=1;always #10 clk=~clk;
 reg [5:0] divider=0;
 wire tick=divider==49;
 always @(posedge clk) if(rst || tick) divider<=0;else divider<=divider+1'b1;
 reg new_seen=0,old_seen=0;
 wire [2:0] new_row,old_row;
 wire [23:0] new_colors,old_colors;
 wire [31:0] unused_new,unused_old;
 wire [7:0] nr,orr,nred,ored,ngreen,ogreen;
 time new_red=0,old_red=0;
 display_compose #(.SUPPORT_CONTINUOUS(1)) nc(
 .system_state(2'd3),.blink_2hz(1'b0),.angle_idx(3'd4),.distance_bcd(16'h0100),.current_valid(1'b1),
 .hist_level0(3'd0),.hist_level1(3'd0),.hist_level2(3'd0),.hist_level3(3'd0),.hist_level4(3'd5),
 .hist_valid({new_seen,4'b0}),.hist_seen({new_seen,4'b0}),.row_idx(new_row),
 .digit_codes(unused_new),.row_colors(new_colors),.continuous_mode(1'b1),.continuous_angle_bcd(12'h180));
 display_compose #(.SUPPORT_CONTINUOUS(1)) oc(
 .system_state(2'd3),.blink_2hz(1'b0),.angle_idx(3'd4),.distance_bcd(16'h0100),.current_valid(1'b1),
 .hist_level0(3'd0),.hist_level1(3'd0),.hist_level2(3'd0),.hist_level3(3'd0),.hist_level4(3'd5),
 .hist_valid({old_seen,4'b0}),.hist_seen({old_seen,4'b0}),.row_idx(old_row),
 .digit_codes(unused_old),.row_colors(old_colors),.continuous_mode(1'b1),.continuous_angle_bcd(12'h180));
 matrix_scan nm(clk,rst,tick,1'b1,new_colors,new_row,nr,nred,ngreen);
 matrix_scan om(clk,rst,tick,1'b1,old_colors,old_row,orr,ored,ogreen);
 always @(posedge clk) begin
  #1;
  if(!new_red && !nr[4] && nred[0]) new_red=$time;
  if(!old_red && !orr[4] && ored[0]) old_red=$time;
 end
 initial begin
  repeat(3) @(negedge clk);rst=0;
  #4650000;new_seen=1;
  #20000000;old_seen=1;
  wait(old_red!=0);#1;
  $display("MATRIX_LATENCY sample_delta_ns=20000000 new_visible_ns=%0d old_visible_ns=%0d visible_delta_ns=%0d",new_red,old_red,old_red-new_red);
  if(old_red-new_red<=20000000) $fatal(1,"Counterexample phase not reproduced");
  $display("CONFIRMED_BOUND_EXCEEDED: unchanged matrix multiplexing amplifies a 20ms history update shift; no old expectation changed");
  $finish;
 end
 initial begin #40000000;$fatal(1,"Timeout");end
endmodule
