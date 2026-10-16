`timescale 1ns/1ps
module lcd_p1_core #(
 parameter ENABLE_READBACK=0,
 parameter integer RESET_CYCLES=50000,
 parameter integer WAIT_CYCLES=1000000
)(input wire clk, rst, input wire [7:0] data_in,
 output wire [7:0] data_out, output wire data_oe,
 output wire lcd_rd_n,lcd_wr_n,lcd_a0,lcd_rst_n,lcd_cs_n,
 output wire [7:0] led, output wire finished);
 wire ready,done,initialized,init_req,init_a0;
 wire [7:0] init_data,read_data,pattern;
 reg [3:0] state;
 reg pending;
 reg [2:0] page;
 reg [6:0] col;
 reg [7:0] result;
 reg req,a0,read_op;
 reg [7:0] data;
 // Write-only draws 1024 bytes. Readback tests page 0, column 0.
 localparam PAGE=0,HI=1,LO=2,DATA=3,RPAGE=4,RHI=5,RLO=6,DUMMY=7,READ=8,END=9;
 lcd_p1_pattern image({page,col},pattern);
 lcd_init #(.RESET_CYCLES(RESET_CYCLES),.WAIT_CYCLES(WAIT_CYCLES)) init(
  clk,rst,ready,done,init_req,init_a0,init_data,lcd_rst_n,initialized,1'b1);
 lcd_bus #(.ENABLE_READBACK(ENABLE_READBACK)) bus(
  .clk(clk),.rst(rst),.request(initialized ? req : init_req),
  .read_op(initialized && read_op),.data_op(initialized ? a0 : init_a0),
  .write_data(initialized ? data : init_data),.data_in(data_in),
  .data_out(data_out),.data_oe(data_oe),.ready(ready),.done(done),.read_data(read_data),
  .lcd_rd_n(lcd_rd_n),.lcd_wr_n(lcd_wr_n),.lcd_a0(lcd_a0),.lcd_cs_n(lcd_cs_n));
 assign led=ENABLE_READBACK ? result : {8{finished}};
 assign finished=state==END;
 always @* begin
  req=initialized && ready && !pending && state!=END;
  a0=state==DATA || state==DUMMY || state==READ;
  read_op=ENABLE_READBACK && (state==DUMMY || state==READ);
  case(state)
   PAGE,RPAGE:data=8'hb0|{5'b0,page};
   HI,RHI:data=8'h10;
   LO,RLO:data=0;
   DATA:data=ENABLE_READBACK ? 8'hff : pattern;
   default:data=0;
  endcase
 end
 always @(posedge clk) begin
  if(rst) begin state<=PAGE; pending<=0; page<=0; col<=0; result<=0; end
  else if(initialized) begin
   if(req) pending<=1;
   if(done && pending) begin
    pending<=0;
    case(state)
     PAGE:state<=HI;
     HI:state<=LO;
     LO:state<=DATA;
     DATA:if(ENABLE_READBACK) state<=RPAGE;
      else if(col==127) begin
       col<=0;
       if(page==7) state<=END;
       else begin page<=page+1'b1; state<=PAGE; end
      end else col<=col+1'b1;
     RPAGE:state<=RHI;
     RHI:state<=RLO;
     RLO:state<=DUMMY;
     DUMMY:state<=READ;
     READ:begin result<=read_data; state<=END; end
     default:state<=END;
    endcase
   end
  end
 end
endmodule
