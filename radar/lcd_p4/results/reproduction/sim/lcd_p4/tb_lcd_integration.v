`timescale 1ns/1ps
module tb_lcd_integration;
 reg clk=0,rst=1,enable=0;always #10 clk=~clk;
 reg [7:0] beam_angle=0,sample_angle=0;reg beam_direction_up=1,sample_direction_up=1;
 reg measure_start=0,measure_done=0,radius_valid=0;reg [5:0] radius=0;
 wire request,direction_up,valid,plot_only,ready,done,initialized,oe,rd,wr,a0,res,cs;
 wire [7:0] angle,dout,data;wire [5:0] draw_radius;
 assign data=oe?dout:8'bz;
 radar_lcd_bridge bridge(clk,rst,enable,beam_angle,beam_direction_up,measure_start,measure_done,
  sample_angle,sample_direction_up,radius,radius_valid,ready,done,
  request,angle,direction_up,draw_radius,valid,plot_only);
 lcd_p4_core #(.ENABLE_READBACK(1),.USE_UFM(0),.RESET_CYCLES(10),.WAIT_CYCLES(20)) dut(
  clk,rst,request,plot_only,angle,direction_up,draw_radius,valid,ready,done,initialized,
  data,dout,oe,rd,wr,a0,res,cs);
 st7565_model model(res,cs,rd,wr,a0,oe,data);
 integer nonring_writes=0;
 integer a_count=0,b_count=0,updates=0,j,a_before,b_before,beam_count=0,target_count=0;
 reg [7:0] before_ram[0:1055];
 always @(posedge clk) if(!rst) begin
  if(dut.draw.state==4 && dut.draw.transaction==7 && dut.draw.bus_done && dut.draw.pending && !dut.draw.erase &&
     dut.draw.pixel_step!=16 && dut.draw.pixel_step!=32 && dut.draw.pixel_step!=48)
   nonring_writes=nonring_writes+1;
  if(dut.draw.state==1) a_count=a_count+1;
  if(dut.draw.state==2) b_count=b_count+1;
  if(request && ready) begin
   updates=updates+1;
   if(plot_only) target_count=target_count+1;else beam_count=beam_count+1;
  end
 end
 task step;begin @(negedge clk);end endtask
 task await_done;begin wait(done);step;repeat(4) step;end endtask
 task beam;
  input [7:0] a;input d;input integer expected_a;
  begin
   a_before=a_count;b_before=b_count;beam_angle=a;beam_direction_up=d;
   await_done;
   if(a_count-a_before!=expected_a || b_count-b_before!=1)
    $fatal(1,"A/B count angle=%0d dir=%b A=%0d expected=%0d B=%0d",a,d,a_count-a_before,expected_a,b_count-b_before);
  end
 endtask
 task target;
  input [7:0] a;input d;input [5:0] r;input v;
  integer k,nonring_before;
  begin
   for(k=0;k<1056;k=k+1) before_ram[k]=model.ram[k];
   nonring_before=nonring_writes;
   a_before=a_count;b_before=b_count;
   measure_start=1;step;measure_start=0;
   sample_angle=a;sample_direction_up=d;radius=r;radius_valid=v;measure_done=1;step;measure_done=0;
   wait(request);#1;
   if(angle!==a || direction_up!==d || draw_radius!==r || valid!==v || !plot_only)
    $fatal(1,"Result/sample binding failed");
   wait(dut.draw.state==2);#1;
   if(dut.draw.current_angle!==a || dut.draw.target_radius!==(r<6?6:r) || dut.draw.target_valid!==v)
    $fatal(1,"Core target angle/radius latch or minimum-radius clamp failed");
   await_done;
   if(v && r!=16 && r!=32 && r!=48) begin
    if(nonring_writes-nonring_before!=1) $fatal(1,"Missing non-ring target write");
   end else if(nonring_writes!=nonring_before) $fatal(1,"Invalid target wrote an extra point");
   if(a_count!=a_before || b_count-b_before!=1) $fatal(1,"Target repeated erase phase");
   for(k=0;k<1056;k=k+1) if((model.ram[k]&before_ram[k])!==before_ram[k])
    $fatal(1,"B-only target erased existing pixels addr=%0d",k);
  end
 endtask
 initial begin
  repeat(4) step;rst=0;wait(initialized);step;enable=1;
  a_before=a_count;b_before=b_count;await_done;
  if(a_count-a_before!=11 || b_count-b_before!=1) $fatal(1,"Initial endpoint batch missing");
  for(j=1;j<=180;j=j+1) begin
   if(j<=170) beam(j,1,1);else beam(j,1,0);
  end
  if(beam_count!=181) $fatal(1,"Did not preserve all 181 integer beams count=%0d",beam_count);
  beam(180,0,11);
  target(172,0,2,1);target(140,0,24,1);target(130,0,48,1);
  target(120,0,24,0);
  beam(179,0,1);beam(10,0,1);beam(0,1,11);
  if(model.reads==0 || model.clear_writes!=1056) $fatal(1,"LCD model saw no RMW or incorrect clear");
  $display("PASS tb_lcd_integration beams=%0d targets=%0d updates=%0d A=%0d B=%0d model_reads=%0d; all181 integer beams, sample-bound B-only, invalid target, both endpoint batches",beam_count,target_count,updates,a_count,b_count,model.reads);
  $finish;
 end
 initial begin #2000000000;$fatal(1,"LCD integration timeout");end
endmodule

