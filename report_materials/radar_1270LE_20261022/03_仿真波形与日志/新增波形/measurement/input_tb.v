`timescale 1ns/1ps
module tb_report_measure;
 reg clk=0,rst=1,start=0,cancel=0,echo=0;
 always #10 clk=~clk;
 integer usphase=0,msphase=0;
 wire tick_us=usphase==49,tick_ms=msphase==49999;
 always @(posedge clk)begin
  if(rst)begin usphase<=0;msphase<=0;end
  else begin usphase<=tick_us?0:usphase+1;msphase<=tick_ms?0:msphase+1;end
 end
 wire trig,busy,done,valid,rv; wire [15:0] bcd;wire [2:0] level;wire [5:0] radius;
 ultrasonic_bcd_budget_compact dut(.clk(clk),.rst(rst),.tick_us(tick_us),.tick_ms(tick_ms),
 .measure_start(start),.cancel(cancel),.echo_async(echo),.trig(trig),.measure_busy(busy),
 .measure_done(done),.distance_bcd(bcd),.distance_valid(valid),.distance_level(level),
 .radius(radius),.radius_valid(rv));
 integer n,expected,samples=0;
 initial begin
  $dumpfile("trace.vcd");$dumpvars(0,start,echo,trig,busy,done,valid,bcd,level,radius,rv);
 end
 task launch;begin
  @(negedge clk);start=1;@(negedge clk);start=0;wait(trig);wait(!trig);
  repeat(7)@(negedge clk);
 end endtask
 task pulse;input integer mm;begin
  launch;echo=1;repeat(mm*294+1)@(negedge clk);echo=0;
  wait(done);#1;n=bcd[15:12]*1000+bcd[11:8]*100+bcd[7:4]*10+bcd[3:0];
  expected=mm>=800?1:mm>=600?2:mm>=400?3:mm>=200?4:5;
  if(n!=mm || !valid || level!=expected)$fatal(1,"measurement mismatch mm=%0d got=%0d",mm,n);
  $display("MEASURE time_ps=%0t mm=%0d bcd=%04x level=%0d radius=%0d",$time,n,bcd,level,radius);
  // Keep the valid result visible for 200us before the next independent test.
  samples=samples+1;repeat(10000)@(negedge clk);
 end endtask
 initial begin
  repeat(4)@(negedge clk);rst=0;
  pulse(20);pulse(199);pulse(200);pulse(800);pulse(1200);pulse(4000);
  launch;wait(done);#1;if(valid || rv)$fatal(1,"timeout validity");
  $display("PASS report_measure six valid distances and no-echo timeout; physical clock 50MHz");$finish;
 end
 initial begin #150000000;$fatal(1,"measurement timeout");end
endmodule
