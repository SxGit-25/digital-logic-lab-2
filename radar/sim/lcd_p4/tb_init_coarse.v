`timescale 1ns/1ps
module coarse_case #(parameter PHASE=0)(output reg complete=0);
 reg clk=0,rst=1;
 always #10 clk=~clk;
 integer cycle=0,start_cycle,reset_end,first_command=-1,power_command=-1;
 wire delay_tick=(cycle%7)==PHASE;
 wire ready,done,req,a0,lcd_reset,initialized,oe,rd,wr,cs,bus_a0;
 wire [7:0] command,out;
 wire [7:0] data=oe ? out : 8'bz;
 wire [7:0] read_data;
 lcd_init #(.RESET_CYCLES(15),.WAIT_CYCLES(31),.WAIT_TICK_CYCLES(7)) init(
 clk,rst,ready,done,req,a0,command,lcd_reset,initialized,delay_tick);
 lcd_bus #(.ENABLE_READBACK(0),.STABLE_WRITE(1)) bus(
 clk,rst,req,1'b0,a0,command,data,out,oe,ready,done,read_data,rd,wr,bus_a0,cs);
 st7565_model model(lcd_reset,cs,rd,wr,bus_a0,oe,data);
 always @(posedge clk) cycle=cycle+1;
 initial begin
  repeat(3) @(negedge clk);start_cycle=cycle;rst=0;
  @(posedge lcd_reset);reset_end=cycle;
  if(reset_end-start_cycle<15) $fatal(1,"Reset shorter than specified minimum");
  wait(initialized);#1;
  if(model.clear_writes!=1056 || !model.display_on || model.reads!=0) $fatal(1,"Initialization incomplete");
  $display("PASS coarse init phase=%0d reset_cycles=%0d clear=1056 RD=high",PHASE,reset_end-start_cycle);
  complete=1;
 end
 always @(negedge wr) if(lcd_reset && !cs && !bus_a0) begin
  if(first_command<0) begin
   first_command=cycle;
   if(cycle-reset_end<31) $fatal(1,"Post-reset wait shorter than specified minimum");
  end
  if(command==8'h2f) power_command=cycle;
  if(command==8'h24 && (power_command<0 || cycle-power_command<31)) $fatal(1,"Power wait too short");
 end
endmodule
module tb_init_coarse;
 wire [6:0] complete;
 genvar i;
 generate for(i=0;i<7;i=i+1) begin:g
  coarse_case #(.PHASE(i)) test(complete[i]);
 end endgenerate
 initial begin wait(&complete);$display("PASS tb_init_coarse all 7 tick phases, protocol model and delay minima");$finish;end
 initial begin #1000000;$fatal(1,"Timeout");end
endmodule
