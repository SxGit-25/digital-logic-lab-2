`timescale 1ns/1ps
module tb_bridge_integration;
 reg clk=0,rst=1,enable=0;always #10 clk=~clk;
 reg [7:0] beam_angle=0,sample_angle=0;
 reg beam_direction_up=1,sample_direction_up=1,measure_start=0,measure_done=0;
 reg [5:0] radius=0;reg radius_valid=0,lcd_ready=0,lcd_done=0;
 wire request,direction_up,draw_valid,plot_only;wire [7:0] angle;wire [5:0] draw_radius;
 radar_lcd_bridge dut(clk,rst,enable,beam_angle,beam_direction_up,measure_start,measure_done,
  sample_angle,sample_direction_up,radius,radius_valid,lcd_ready,lcd_done,
  request,angle,direction_up,draw_radius,draw_valid,plot_only);
 integer count=0;
 reg [22:0] held;
 task step;begin @(negedge clk);end endtask
 task accept;
  input [7:0] a;input d,p;input [5:0] r;input v;
  begin
   lcd_ready=1;wait(request);#1;
   if({angle,direction_up,plot_only,draw_radius,draw_valid}!=={a,d,p,r,v})
    $fatal(1,"Bridge request mismatch n=%0d angle=%0d dir=%b plot=%b r=%0d valid=%b",count,angle,direction_up,plot_only,draw_radius,draw_valid);
   held={angle,direction_up,plot_only,draw_radius,draw_valid};count=count+1;
   step;lcd_ready=0;
   repeat(3) begin step;if({angle,direction_up,plot_only,draw_radius,draw_valid}!==held) $fatal(1,"Busy request arguments changed");end
  end
 endtask
 task finish_work;begin lcd_done=1;step;lcd_done=0;step;end endtask
 task start_measure;begin measure_start=1;step;measure_start=0;end endtask
 task result;
  input [7:0] a;input d;input [5:0] r;input v;
  begin sample_angle=a;sample_direction_up=d;radius=r;radius_valid=v;measure_done=1;step;measure_done=0;end
 endtask
 initial begin
  repeat(3) step;rst=0;enable=1;step;step;
  accept(0,1,0,0,0);
  // Queue both while active. Beam wins; result keeps captured sample identity.
  start_measure;beam_angle=10;step;result(3,1,17,1);
  repeat(3) step;
  if({angle,direction_up,plot_only,draw_radius,draw_valid}!==held) $fatal(1,"Queued event changed active payload");
  finish_work;accept(10,1,0,0,0);finish_work;accept(3,1,1,17,1);finish_work;
  // A result from before turnaround cannot repaint after the endpoint batch.
  start_measure;beam_angle=180;beam_direction_up=0;step;
  result(179,1,33,1);accept(180,0,0,0,0);finish_work;
  lcd_ready=1;repeat(10) begin step;if(request) $fatal(1,"Old epoch result survived turnaround");end
  lcd_ready=0;start_measure;result(178,0,5,1);accept(178,0,1,5,1);finish_work;
  start_measure;beam_angle=0;beam_direction_up=1;step;result(1,0,20,1);
  accept(0,1,0,0,0);finish_work;
  lcd_ready=1;repeat(10) begin step;if(request) $fatal(1,"Old descending epoch result survived");end
  // Disabling clears both pending queues; re-enable starts a fresh beam.
  lcd_ready=0;beam_angle=22;step;start_measure;result(20,1,10,1);enable=0;step;step;
  if(request) $fatal(1,"Disabled bridge requested LCD");
  enable=1;beam_angle=30;step;step;accept(30,1,0,0,0);finish_work;
  lcd_ready=1;repeat(10) begin step;if(request) $fatal(1,"Disable retained a pending request");end
  $display("PASS tb_bridge_integration requests=%0d; beam priority, sampled target, busy stability, both epoch turns, disable queue reset",count);$finish;
 end
 initial begin #100000;$fatal(1,"Bridge timeout");end
endmodule
