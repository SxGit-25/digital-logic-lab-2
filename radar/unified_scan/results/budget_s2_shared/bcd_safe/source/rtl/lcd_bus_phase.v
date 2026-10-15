`timescale 1ns/1ps
// Input write_data remains stable until done. One elapsed-phase counter owns
// setup, strobe, recovery and read turnaround; no duplicated state timer.
module lcd_bus_phase #(
 parameter ENABLE_READBACK=0,
 parameter SETUP_CYCLES=4,WRITE_CYCLES=6,READ_CYCLES=10,
 parameter HOLD_CYCLES=6,TURN_CYCLES=20
)(
 input wire clk,rst,request,read_op,data_op,
 input wire [7:0] write_data,data_in,
 output wire [7:0] data_out,
 output wire data_oe,ready,
 output reg done,
 output reg [7:0] read_data,
 output wire lcd_rd_n,lcd_wr_n,
 output reg lcd_a0,
 output wire lcd_cs_n
);
 function integer width;
 input integer n;
 begin width=1;while((2**width)<=n) width=width+1;end
 endfunction
 localparam W_END=SETUP_CYCLES+WRITE_CYCLES+HOLD_CYCLES;
 localparam R_BEGIN=TURN_CYCLES+SETUP_CYCLES+1;
 localparam R_END=TURN_CYCLES+SETUP_CYCLES+READ_CYCLES+HOLD_CYCLES;
 reg [width(R_END>W_END ? R_END : W_END)-1:0] phase;
 reg reading;
 reg [7:0] saved_write_data;
 assign ready=phase==0;
 assign data_out=saved_write_data;
 assign data_oe=!ENABLE_READBACK || (!reading && !ready);
 assign lcd_cs_n=ready || (reading && phase<=TURN_CYCLES);
 assign lcd_wr_n=!(phase>SETUP_CYCLES && phase<=SETUP_CYCLES+WRITE_CYCLES && !reading);
 assign lcd_rd_n=!(ENABLE_READBACK && reading && phase>=R_BEGIN && phase<R_BEGIN+READ_CYCLES);
 always @(posedge clk) begin
  if(rst) begin phase<=0;reading<=0;lcd_a0<=0;done<=0;read_data<=0;saved_write_data<=0;end
  else begin
   done<=0;
   if(ready) begin
    if(request && (!read_op || ENABLE_READBACK)) begin
     reading<=ENABLE_READBACK && read_op;lcd_a0<=data_op;phase<=1;saved_write_data<=write_data;
    end
   end else begin
    if(ENABLE_READBACK && reading && phase==R_BEGIN+READ_CYCLES-2) read_data<=data_in;
    if(phase==(reading ? R_END : W_END)) begin phase<=0;done<=1;end
    else phase<=phase+1'b1;
   end
  end
 end
endmodule
