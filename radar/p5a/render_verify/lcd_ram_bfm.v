`timescale 1ns/1ps
// Transaction-level ST7565 RAM model. Physical bus timings/turnaround are
// verified by the existing real lcd_bus tests; this retains RAM read semantics.
module lcd_ram_bfm #(parameter REAL_TIMING=0)(
 input wire clk,rst,request,read_op,data_op,
 input wire [7:0] write_data,
 output wire ready,output reg done,
 output reg [7:0] read_data
);
 reg [7:0] ram[0:1055];
 reg [2:0] page;
 reg [7:0] col,buffer;
 integer buffer_address;
 reg dummy,contrast_pending,pending;
 reg held_read,held_data;
 reg [7:0] held_byte;
 integer reads,writes,commands,i;
 integer remaining;
 assign ready=!pending;
 always @(posedge clk) begin
  if(rst) begin
   done<=0;pending<=0;remaining<=0;read_data<=0;page<=0;col<=0;
   buffer<=8'hxx;buffer_address<=0;dummy<=1;contrast_pending<=0;
   reads<=0;writes<=0;commands<=0;
   for(i=0;i<1056;i=i+1) ram[i]<=8'ha5;
  end else begin
   done<=0;
   if(request && ready && !done) begin
    pending<=1;held_read<=read_op;held_data<=data_op;held_byte<=write_data;
    remaining<=REAL_TIMING ? (read_op ? 39 : 15) : 0;
   end
   if(pending && remaining!=0) remaining<=remaining-1;
   if(pending && remaining==0) begin
    pending<=0;done<=1;
    if(held_read) begin
     if(!held_data || col>131) $fatal(1,"Invalid LCD data read");
     read_data<=dummy ? 8'hxx : buffer;
     buffer<=ram[page*132+col];buffer_address<=page*132+col;dummy<=0;
     col<=col==131?0:col+1'b1;reads<=reads+1;
    end else if(held_data) begin
     if(col>131) $fatal(1,"LCD write column out of bounds");
     ram[page*132+col]<=held_byte;
     col<=col==131?0:col+1'b1;writes<=writes+1;
    end else begin
     commands<=commands+1;
     if(contrast_pending) contrast_pending<=0;
     else if(held_byte==8'h81) contrast_pending<=1;
     else if(held_byte[7:4]==4'hb) begin page<=held_byte[2:0];dummy<=1;end
     else if(held_byte[7:4]==4'h1) begin col[7:4]<=held_byte[3:0];dummy<=1;end
     else if(held_byte[7:4]==4'h0) begin col[3:0]<=held_byte[3:0];dummy<=1;end
    end
   end
  end
 end
endmodule
