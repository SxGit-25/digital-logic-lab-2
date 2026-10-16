`timescale 1ns/1ps
module tb_ultrasonic_bcd_budget;
 reg clk=0,rst=1,start=0,cancel=0,echo=0;
 always #10 clk=~clk;
 integer usphase=0,msphase=0;
 wire tick_us=usphase==49,tick_ms=msphase==49999;
 always @(posedge clk)begin
  if(rst)begin usphase<=0;msphase<=0;end
  else begin usphase<=tick_us?0:usphase+1;msphase<=tick_ms?0:msphase+1;end
 end
 wire trig,busy,done,valid,rv;
 wire [15:0] bcd;
 wire [2:0] level;
 wire [5:0] radius;
 ultrasonic_bcd_budget dut(.clk(clk),.rst(rst),.tick_us(tick_us),.tick_ms(tick_ms),
  .measure_start(start),.cancel(cancel),.echo_async(echo),.trig(trig),
  .measure_busy(busy),.measure_done(done),.distance_bcd(bcd),
  .distance_valid(valid),.distance_level(level),.radius(radius),.radius_valid(rv));
 integer samples=0,numeric,expected,expectedlevel;
 real ideal,error,maxerror=0;
 task launch;
 begin @(negedge clk);start=1;@(negedge clk);start=0;
 wait(trig);wait(!trig);repeat(7)@(negedge clk);end
 endtask
 task pulse;
 input integer clocks;
 begin
  launch;echo=1;repeat(clocks)@(negedge clk);echo=0;
  wait(done);#1;
  numeric=1000*bcd[15:12]+100*bcd[11:8]+10*bcd[7:4]+bcd[3:0];
  expected=(clocks-1)/294;
  if(numeric!==expected)$fatal(1,"count %0d expected %0d for %0d clocks",numeric,expected,clocks);
  if(valid!==(expected>=20&&expected<=4000))$fatal(1,"valid boundary %0d",expected);
  if(valid)begin
   ideal=clocks*0.0034;error=numeric-ideal;if(error<0)error=-error;
   if(error>maxerror)maxerror=error;
   if(error>2.0)$fatal(1,"ideal error %f",error);
   expectedlevel=expected>=800?1:expected>=600?2:expected>=400?3:expected>=200?4:5;
   if(level!==expectedlevel)$fatal(1,"threshold %0d",expected);
   if(rv!==(expected<=1200))$fatal(1,"radius validity %0d",expected);
   if(expected<=1200&&radius!==expected/25)$fatal(1,"radius %0d",expected);
  end
  samples=samples+1;repeat(8)@(negedge clk);
 end endtask
 initial begin
  repeat(4)@(negedge clk);rst=0;
  pulse(19*294+1);pulse(20*294+1);pulse(199*294+1);pulse(200*294+1);
  pulse(399*294+1);pulse(400*294+1);pulse(599*294+1);pulse(600*294+1);
  pulse(799*294+1);pulse(800*294+1);pulse(1199*294+1);pulse(1200*294+1);
  pulse(1201*294+1);pulse(3999*294+1);pulse(4000*294+1);pulse(4001*294+1);
  // Falling edge during the four-clock serialized decimal update.
  pulse(200*294+2);pulse(200*294+3);pulse(200*294+4);
  launch;wait(done);#1;if(valid||rv)$fatal(1,"missing echo timeout");
  repeat(4)@(negedge clk);launch;echo=1;wait(done);#1;
  if(valid||rv)$fatal(1,"long echo timeout");echo=0;
  repeat(4)@(negedge clk);echo=1;launch;wait(done);#1;
  if(valid||rv)$fatal(1,"preexisting high echo");echo=0;
  repeat(4)@(negedge clk);launch;echo=1;repeat(300)@(negedge clk);
  cancel=1;@(negedge clk);cancel=0;echo=0;repeat(8)@(negedge clk);
  if(busy||valid||rv||trig)$fatal(1,"cancel");
  pulse(20*294+1);
  $display("PASS tb_ultrasonic_bcd_budget samples=%0d max_ideal_error_mm=%f",samples,maxerror);$finish;
 end
 initial begin #400000000;$fatal(1,"test timeout");end
endmodule
