`timescale 1ns/1ps
// Two equal samples spaced 20ms apart; switches share the global sample tick.
module switch_pair_sampled(
 input wire clk,rst,sample_tick,
 input wire sw6,sw7,
 output reg mode_continuous,system_on,
 output wire sw7_sync
);
 reg [1:0] sw_meta,sw_sync,previous;
 assign sw7_sync=sw_sync[0];
 always @(posedge clk) begin
  if(rst) begin sw_meta<=0;sw_sync<=0;previous<=0;mode_continuous<=0;system_on<=0;end
  else begin
   sw_meta<={sw6,sw7};sw_sync<=sw_meta;
   if(sample_tick) begin
    previous<=sw_sync;
    if(previous[1]==sw_sync[1])mode_continuous<=sw_sync[1];
    if(previous[0]==sw_sync[0])system_on<=sw_sync[0];
   end
  end
 end
endmodule
