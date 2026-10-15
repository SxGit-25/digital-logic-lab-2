`timescale 1ns/1ps
`define CTRL_PORTS(o) .clk(clk),.rst(rst),.tick_ms(tick),.system_on(on),.angle_applied(applied),.measure_busy(busy),.measure_done(done),.distance_mm(mm),.distance_valid(valid),.continuous_mode(mode),.continuous_angle(angle),.continuous_direction_up(dir),.system_state(o[60:59]),.servo_enable(o[58]),.angle_idx(o[57:55]),.measure_start(o[54]),.measure_cancel(o[53]),.sample_idx(o[52:50]),.current_distance(o[49:38]),.current_valid(o[37]),.current_level(o[36:34]),.hist_level0(o[33:31]),.hist_level1(o[30:28]),.hist_level2(o[27:25]),.hist_level3(o[24:22]),.hist_level4(o[21:19]),.hist_valid(o[18:14]),.hist_seen(o[13:9]),.sample_angle(o[8:1]),.sample_direction_up(o[0])
module ctrl_counter_case #(parameter ID=0,SELF=1,STANDBY=1,SLOT=8,SETTLE=1,SAMPLE=60,SUPPORT=1)(output reg finished=0);
 reg clk=0;always #5 clk=~clk;
 reg rst=1,on=0,tick=1,applied=0,busy=0,done=0,valid=0,mode=0,dir=1;
 reg [7:0] angle=0;reg [11:0] mm=0;
 wire [60:0] actual,expected;
 radar_ctrl #(.SELF_TEST_MS(SELF),.STANDBY_MS(STANDBY),.SLOT_MS(SLOT),.SETTLE_MS(SETTLE),.CONTINUOUS_SAMPLE_MS(SAMPLE),.SUPPORT_CONTINUOUS(SUPPORT)) dut(`CTRL_PORTS(actual));
 radar_ctrl_counter_legacy #(.SELF_TEST_MS(SELF),.STANDBY_MS(STANDBY),.SLOT_MS(SLOT),.SETTLE_MS(SETTLE),.CONTINUOUS_SAMPLE_MS(SAMPLE),.SUPPORT_CONTINUOUS(SUPPORT)) old(`CTRL_PORTS(expected));
 integer cycle,rng=32'h27182818,starts=0,run_cycles=0;
 initial begin
  rng=rng+ID;
  for(cycle=0;cycle<120000;cycle=cycle+1) begin
   @(negedge clk);rng=rng*1664525+1013904223;
   rst=cycle<3 || cycle==60000 || cycle==90000;
   on=cycle>=4 && !(cycle>=40000 && cycle<40007);
   // Directed full-rate basic and continuous windows, then sparse/random ticks.
   mode=cycle>=20000 && cycle<60000 || cycle>=90000;
   tick=cycle<65000 ? 1'b1 : (rng&7)!=0;
   applied=(rng&15)==0;busy=(rng&63)==0;
   done=(rng&31)==0;valid=(rng&127)!=0;
   mm=(rng>>8)&4095;angle=((rng>>16)&255)%181;dir=rng[29];
   @(posedge clk);#1;
   if(actual!==expected) $fatal(1,"CTRL mismatch ID=%0d cycle=%0d out=%h expected=%h timer=%0d old_state=%0d old_slot=%0d",ID,cycle,actual,expected,dut.timer_ms,old.state_ms,old.slot_ms);
   if(dut.state_ms!==old.state_ms || dut.slot_ms!==old.slot_ms || dut.settle_ms!==old.settle_ms)
    $fatal(1,"CTRL timer alias mismatch ID=%0d cycle=%0d",ID,cycle);
   if(actual[54]) starts=starts+1;
   if(actual[60:59]==3) run_cycles=run_cycles+1;
  end
  if(starts==0 || run_cycles<10000) $fatal(1,"CTRL inadequate coverage ID=%0d starts=%0d run=%0d",ID,starts,run_cycles);
  $display("PASS ctrl_counter_case ID=%0d SELF=%0d STANDBY=%0d SLOT=%0d SAMPLE=%0d SUPPORT=%0d cycles=%0d starts=%0d",ID,SELF,STANDBY,SLOT,SAMPLE,SUPPORT,cycle,starts);
  finished=1;
 end
endmodule
module tb_ctrl_counter_integration;
 wire [8:0] finished;
 ctrl_counter_case #(0,1,1,1,1,1,1) c0(finished[0]);
 ctrl_counter_case #(1,2,3,5,1,8,1) c1(finished[1]);
 ctrl_counter_case #(2,257,1,3,1,60,1) c2(finished[2]);
 ctrl_counter_case #(3,1,513,3,2,60,1) c3(finished[3]);
 ctrl_counter_case #(4,1,2,1025,3,60,1) c4(finished[4]);
 ctrl_counter_case #(5,3,4,7,1,2049,1) c5(finished[5]);
 ctrl_counter_case #(6,2000,2000,2000,300,60,1) c6(finished[6]);
 ctrl_counter_case #(7,17,1,1024,15,2049,0) c7(finished[7]);
 ctrl_counter_case #(8,1,4097,1024,16,2,0) c8(finished[8]);
 initial begin wait(&finished);$display("PASS tb_ctrl_counter_integration: 1080000 cycle-pairs, all outputs and timer aliases, 9 width/parameter configurations, rst/on/basic/continuous/tick/busy/done randomization");$finish;end
 initial begin #2000000;$fatal(1,"CTRL counter timeout");end
endmodule
