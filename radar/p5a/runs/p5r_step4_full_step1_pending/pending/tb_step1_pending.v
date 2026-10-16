`timescale 1ns/1ps
module tb_step1_pending;
 reg clk=0,rst=1,request=0;always #10 clk=~clk;
 reg [11:0] angle=0;reg [5:0] radius=0;reg valid=1;
 wire ready,done,initialized,breq,bread,ba0,bready;
 wire [7:0] dropped,bdata;
 reg bdone=0; integer accepted=0,finished=0;
 reg [5:0] snapshot_radius=0;reg snapshot_valid=0;
 assign bready=!bdone;
 always @(posedge clk) bdone<=breq && bready;
 radar_lcd_micro #(.ENABLE_READBACK(1),.P5_FIXES(1)) dut(
  .clk(clk),.rst(rst),.request(request),.tick_ms(1'b1),.continuous_mode(1'b0),
  .initialized(initialized),.lcd_rst_n(),.angle_bcd(angle),.direction_up(1'b1),
  .radius(radius),.radius_valid(valid),.ready(ready),.done(done),.dropped(dropped),
  .bus_request(breq),.bus_read_op(bread),.bus_data_op(ba0),.bus_write_data(bdata),
  .bus_ready(bready),.bus_done(bdone),.bus_read_data(8'b0));
 always @(posedge clk) if(!rst && initialized) begin
  // Sample the completion pulse before the acceptance branch's NBA check.
  // Pending acceptance may coincide with the previous request's done pulse.
  if(done) finished=finished+1;
  if(dut.accept) begin
   accepted=accepted+1;
   if(accepted==1 && (dut.draw_angle!==12'h010 || dut.draw_radius!==12)) $fatal(1,"initial snapshot");
   if(accepted==2 && (dut.draw_angle!==12'h030 || dut.draw_radius!==32)) $fatal(1,"pending did not select latest snapshot");
   if(accepted>2) $fatal(1,"unexpected extra rendering");
   #1;snapshot_radius=dut.target_radius;snapshot_valid=dut.target_valid;
  end else if(accepted>0 && !done) begin
   if(dut.target_radius!==snapshot_radius || dut.target_valid!==snapshot_valid) $fatal(1,"snapshot changed while drawing");
  end
 end
 task pulse;input [11:0] a;input [5:0] r;begin
  @(negedge clk);angle=a;radius=r;valid=1;request=1;
  @(negedge clk);request=0;
 end endtask
 initial begin
  repeat(4)@(negedge clk);rst=0;wait(initialized);wait(ready);
  pulse(12'h010,12);repeat(8)@(negedge clk);
  pulse(12'h020,22);repeat(8)@(negedge clk);pulse(12'h030,32);
  angle=12'h137;radius=63;valid=0;
  wait(finished==2);wait(ready);repeat(12)@(negedge clk);
  if(accepted!=2 || dropped!=1 || dut.pending) $fatal(1,"merge count/queue: accepted=%0d merged=%0d",accepted,dropped);
  $display("PASS step1 pending: accepted 10/12 then 30/32, superseded 20/22, merged=1, snapshots stable");$finish;
 end
 initial begin #100000000;$fatal(1,"pending watchdog");end
endmodule
