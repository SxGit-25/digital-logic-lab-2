`timescale 1ns/1ps
`define UP(o) .clk(clk),.rst(rst),.tick_us(tick),.measure_start(start),.cancel(cancel),.echo_async(echo),.trig(o[22]),.measure_busy(o[21]),.measure_done(o[20]),.distance_valid(o[19]),.distance_mm(o[18:7]),.radius_valid(o[6]),.radius(o[5:0])
module ultra_counter_case #(parameter ID=0,TRIG=15,TIMEOUT=30000,RADIUS=1)(output reg finished=0);
 reg clk=0;always #5 clk=~clk;
 reg rst=1,tick=1,start=0,cancel=0,echo=0;
 wire [22:0] actual,expected;
 ultrasonic #(.TRIG_US(TRIG),.TIMEOUT_US(TIMEOUT),.ENABLE_RADIUS(RADIUS)) dut(`UP(actual));
 ultrasonic_counter_legacy #(.TRIG_US(TRIG),.TIMEOUT_US(TIMEOUT),.ENABLE_RADIUS(RADIUS)) old(`UP(expected));
 integer cycles=0,done_count=0,rng=32'h53465768,i;
 always @(posedge clk) begin
  #1;cycles=cycles+1;
  if(actual!==expected) $fatal(1,"ULTRA mismatch ID=%0d cycle=%0d TIMEOUT=%0d radius=%0d actual=%h expected=%h old_echo=%0d work=%0d rem=%0d started=%b over=%b",ID,cycles,TIMEOUT,RADIUS,actual,expected,old.echo_us,dut.distance_work,dut.distance_rem,dut.echo_started,dut.echo_over4000);
  if(actual[20]) done_count=done_count+1;
 end
 task step;begin @(negedge clk);end endtask
 task pulse_start;begin start=1;step;start=0;end endtask
 task settle;begin wait(!actual[21]);repeat(5) step;end endtask
 task echo_case;
  input integer width;
  begin
   echo=0;repeat(5) step;pulse_start;wait(!actual[22]);repeat(8) step;
   echo=1;repeat(width+1) step;echo=0;settle;
  end
 endtask
 initial begin
  rng=rng+ID;repeat(4) step;rst=0;
  echo_case(117);echo_case(118);echo_case(119);
  // Stale nonzero work must not validate a later no-echo or stuck-high timeout.
  pulse_start;settle;
  echo=1;repeat(5) step;pulse_start;settle;echo=0;repeat(5) step;
  echo_case(23528);echo_case(23529);echo_case(23530);
  echo_case(24500);echo_case(29800);
  if(TIMEOUT>65536) echo_case(80000); // repeated 4096-mm wraparound
  // Random clock pauses, resets, cancellation, spurious starts and echo edges.
  for(i=0;i<50000;i=i+1) begin
   rng=rng*1664525+1013904223;
   rst=(rng&16383)==0;cancel=(rng&4095)==0;
   tick=(rng&7)!=0;start=(rng&127)==0;
   if((rng&31)==0) echo=!echo;
   step;
  end
  rst=1;step;rst=0;start=0;cancel=0;echo=0;tick=1;repeat(5) step;
  if(done_count<8) $fatal(1,"ULTRA inadequate coverage ID=%0d done=%0d",ID,done_count);
  $display("PASS ultra_counter_case ID=%0d TRIG=%0d TIMEOUT=%0d RADIUS=%0d cycle_pairs=%0d completions=%0d",ID,TRIG,TIMEOUT,RADIUS,cycles,done_count);
  finished=1;
 end
endmodule
module tb_ultra_counter_integration;
 wire [15:0] finished;
 ultra_counter_case #(0,1,1,0) c0(finished[0]);
 ultra_counter_case #(1,1,1,1) c1(finished[1]);
 ultra_counter_case #(2,2,117,0) c2(finished[2]);
 ultra_counter_case #(3,2,117,1) c3(finished[3]);
 ultra_counter_case #(4,15,119,0) c4(finished[4]);
 ultra_counter_case #(5,15,119,1) c5(finished[5]);
 ultra_counter_case #(6,31,23529,0) c6(finished[6]);
 ultra_counter_case #(7,31,23529,1) c7(finished[7]);
 ultra_counter_case #(8,16,23530,0) c8(finished[8]);
 ultra_counter_case #(9,16,23530,1) c9(finished[9]);
 ultra_counter_case #(10,15,30000,0) c10(finished[10]);
 ultra_counter_case #(11,15,30000,1) c11(finished[11]);
 ultra_counter_case #(12,3,100000,0) c12(finished[12]);
 ultra_counter_case #(13,3,100000,1) c13(finished[13]);
 ultra_counter_case #(14,4,118,0) c14(finished[14]);
 ultra_counter_case #(15,4,118,1) c15(finished[15]);
 initial begin wait(&finished);$display("PASS tb_ultra_counter_integration: 16 parameter/radius configurations, full output cycle equivalence including boundaries, stale work, noecho, cancel/reset/tick pauses and repeated distance wraparound");$finish;end
 initial begin #10000000;$fatal(1,"ULTRA counter timeout");end
endmodule
