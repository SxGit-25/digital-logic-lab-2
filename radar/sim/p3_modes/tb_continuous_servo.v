`timescale 1ns/1ps
module tb_continuous_servo;
reg clk=0; always #5 clk=~clk;
reg rst=1,tick=0,enable=0; reg[2:0] idx=0;
wire old_out,out0,out1,old_ap,ap0,ap1;
baseline_servo_pwm old(.clk(clk),.rst(rst),.tick_us(tick),.enable(enable),.angle_idx(idx),.servo_out(old_out),.angle_applied(old_ap));
servo_pwm basic(.clk(clk),.rst(rst),.tick_us(tick),.enable(enable),.angle_idx(idx),.servo_out(out0),.angle_applied(ap0),.continuous_mode(1'b0),.sweep_run(1'b0));
servo_pwm #(.SUPPORT_CONTINUOUS(1)) mode0(.clk(clk),.rst(rst),.tick_us(tick),.enable(enable),.angle_idx(idx),.servo_out(out1),.angle_applied(ap1),.continuous_mode(1'b0),.sweep_run(1'b1));
wire servo; wire[7:0] angle; wire[11:0] bcd; wire up,frame;
reg cont_enable=0;
servo_pwm #(.SUPPORT_CONTINUOUS(1)) dut(.clk(clk),.rst(rst),.tick_us(tick),.enable(cont_enable),.angle_idx(3'd0),.servo_out(servo),.continuous_mode(1'b1),.sweep_run(1'b1),.continuous_angle(angle),.continuous_angle_bcd(bcd),.direction_up(up),.frame_start(frame));
integer i,j,n,expected,width,observed; integer rng=21;
initial begin
 repeat(3) @(negedge clk); rst=0;
 for(i=0;i<100000;i=i+1) begin
  @(negedge clk); rng=rng*1664525+1013904223; tick=(rng & 7)!=0; idx=(rng>>12)&7; enable=(i%27000)>20; rst=(i%19000)==0;
  @(posedge clk); #1;
  if({old_out,old_ap} !== {out0,ap0} || {old_out,old_ap} !== {out1,ap1}) $fatal(1,"servo baseline cycle %d",i);
 end
 @(negedge clk); rst=1; tick=1; enable=0;
 repeat(2) @(negedge clk); rst=0; cont_enable=1;
 @(posedge clk); #1;
 for(i=0;i<=800;i=i+1) begin
   n=(i<=400)?i:800-i;
   expected=(n*9+10)/20; width=500+5*n;
   if(angle!==expected || (bcd[11:8]*100+bcd[7:4]*10+bcd[3:0])!=expected || up!==(i<400 || i==800))
      $fatal(1,"angle/BCD/direction frame %d got %d %h %b expected %d",i,angle,bcd,up,expected);
   observed=0;
   for(j=0;j<20000;j=j+1) begin
     if(servo) observed=observed+1;
     @(posedge clk); #1;
   end
   if(observed!=width) $fatal(1,"pulse frame %d got %d expected %d",i,observed,width);
 end
 $display("PASS servo baseline 100000 randomized cycles; continuous 801 full 20000-us frames, 500..2500 us, 0->180->0, binary/BCD/direction every frame"); $finish;
end
endmodule
