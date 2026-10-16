`timescale 1ns/1ps
module tb_p5_ui_core;
 parameter P5_DIGITS=1,P5_MODE=1,P5_LEVEL=1;
 reg clk=0,rst=1,request=0,continuous_mode=1;
 reg [11:0] angle_bcd=0;
 reg [15:0] distance_bcd=0;
 reg [2:0] level=0;
 wire ready,done,initialized,breq,bread,ba0,bready;
 wire [7:0] dropped,bdata;
 reg bdone=0;
 integer accepted=0,finished=0,page=0,col=0,ui_count=0;
 reg [11:0] saved_angle;
 reg [15:0] saved_distance;
 always #10 clk=~clk;
 assign bready=!bdone;
 always @(posedge clk)bdone<=breq && bready;
 radar_lcd_micro #(.ENABLE_READBACK(1),.P5_FIXES(1),.P5_DIGITS(P5_DIGITS),.P5_MODE(P5_MODE),.P5_LEVEL(P5_LEVEL)) dut(
  .clk(clk),.rst(rst),.request(request),.tick_ms(1'b1),.continuous_mode(continuous_mode),
  .alarm_active(1'b0),.inverse_phase(1'b0),.initialized(initialized),.lcd_rst_n(),
  .angle_bcd(angle_bcd),.distance_bcd(distance_bcd),.level(level),.direction_up(1'b1),
  .radius(6'd24),.radius_valid(1'b1),.ready(ready),.done(done),.dropped(dropped),
  .bus_request(breq),.bus_read_op(bread),.bus_data_op(ba0),.bus_write_data(bdata),
  .bus_ready(bready),.bus_done(bdone),.bus_read_data(8'b0));
 always @(posedge clk)if(!rst && initialized)begin
  if(done)finished=finished+1;
  if(dut.accept)begin
   accepted=accepted+1;
   #1;
   if(P5_DIGITS)begin
    case(accepted)
     1:if(dut.active_angle!==12'h010 || dut.active_distance!==16'h1234)$fatal(1,"first snapshot");
     2:if(dut.active_angle!==12'h030 || dut.active_distance!==16'h9012)$fatal(1,"pending latest snapshot");
     3:if(dut.active_angle!==12'h135 || dut.active_distance!==16'h0456)$fatal(1,"third snapshot");
     default:$fatal(1,"unexpected accept");
    endcase
    saved_angle=dut.active_angle;saved_distance=dut.active_distance;
   end
  end else if(P5_DIGITS && accepted>0 && !done)begin
   if(dut.active_angle!==saved_angle || dut.active_distance!==saved_distance)$fatal(1,"busy UI snapshot changed");
  end
 end
 always @(posedge clk)if(!rst && breq && dut.state==24)begin
  if(bread)$fatal(1,"UI attempted LCD read");
  if(ba0!==(dut.bit_index[1:0]==3))$fatal(1,"UI command/data direction");
  case(dut.bit_index[1:0])
   0:begin
    if(bdata!==8'hb0 && bdata!==8'hb1)$fatal(1,"UI page command");
    page=bdata[0];
   end
   1:begin if(bdata[7:4]!==1)$fatal(1,"column high");col={bdata[3:0],4'b0};end
   2:begin if(bdata[7:4]!==0)$fatal(1,"column low");col=col|bdata[3:0];end
   3:begin $display("UI %0d %0d %0d %02x",accepted,page,col,bdata);ui_count=ui_count+1;end
  endcase
 end
 task pulse;
  input [11:0] a;input [15:0] d;input [2:0] l;
  begin @(negedge clk);angle_bcd=a;distance_bcd=d;level=l;request=1;
   @(negedge clk);request=0;end
 endtask
 initial begin
  repeat(4)@(negedge clk);rst=0;wait(initialized);wait(ready);
  pulse(12'h010,16'h1234,2);repeat(8)@(negedge clk);
  pulse(12'h020,16'h5678,3);repeat(8)@(negedge clk);pulse(12'h030,16'h9012,5);
  angle_bcd=12'h137;distance_bcd=16'h8888;level=1;
  wait(finished==2);wait(ready);repeat(4)@(negedge clk);
  continuous_mode=0;pulse(12'h135,16'h0456,0);
  angle_bcd=12'h090;distance_bcd=16'h9999;level=4;
  wait(finished==3);wait(ready);repeat(4)@(negedge clk);
  if(accepted!=3 || dropped!=1)$fatal(1,"pending merge");
  $display("PASS UI core requests=%0d merged=%0d columns=%0d digits/mode/level=%0d%0d%0d",accepted,dropped,ui_count,P5_DIGITS,P5_MODE,P5_LEVEL);$finish;
 end
 initial begin #100000000;$fatal(1,"UI core watchdog");end
endmodule
