`timescale 1ns/1ps
module tb_modes_integration;
reg clk=0; always #5 clk=~clk;
reg sw7=0,sw6=0,echo=0;
wire trig,servo,buzzer; wire[15:0] led; wire[7:0] cat,row,cr,cg; wire[6:0] seg;
radar_mode_top #(.CLK_HZ(1000000),.SELF_TEST_MS(2),.STANDBY_MS(2),.SLOT_MS(50),.SETTLE_MS(1),.SWITCH_MS(1),.CONTINUOUS_SAMPLE_MS(4)) dut(
.clk(clk),.sw7(sw7),.sw6(sw6),.echo(echo),.trig(trig),.servo(servo),.buzzer(buzzer),.led(led),.cat_n(cat),.matrix_row_n(row),.matrix_col_r(cr),.matrix_col_g(cg),.seg_a(seg[6]),.seg_b(seg[5]),.seg_c(seg[4]),.seg_d(seg[3]),.seg_e(seg[2]),.seg_f(seg[1]),.seg_g(seg[0]));
integer i,sawself,sawstandby,sawrun; reg[7:0] captured; reg capdir; reg[2:0] capidx;
task cycle; begin @(posedge clk); #1; @(negedge clk); end endtask
task shutcheck; begin #1; if(trig||servo||buzzer||led||seg||cat!==8'hff||row!==8'hff||cr||cg) $fatal(1,"SW7 async cutoff"); end endtask
task transition; input target; begin
 sw6=target;
 wait(dut.mode_changed); @(posedge clk); #1;
 if(dut.hist_seen!==0 || dut.current_valid || dut.measure_busy || !dut.measure_cancel) $fatal(1,"mode reset/cancel/history");
 sawself=0; sawstandby=0; sawrun=0;
 for(i=0;i<6500;i=i+1) begin
  cycle;
  if(dut.system_state==1) sawself=1;
  if(dut.system_state==2) sawstandby=1;
  if(dut.system_state==3) sawrun=1;
 end
 if(!(sawself&&sawstandby&&sawrun)) $fatal(1,"mode must restart SELF STANDBY RUN");
end endtask
initial begin
 repeat(50) cycle; sw7=1; wait(dut.system_state==3); @(negedge clk);
 wait(dut.measure_busy); transition(1);
 wait(trig); wait(!trig); repeat(10) cycle; echo=1; repeat(590) cycle; echo=0;
 wait(dut.measure_done); repeat(5) cycle;
 if(!dut.current_valid || dut.current_distance<95 || dut.current_distance>105 || dut.current_level!==5) $fatal(1,"real ultrasonic integration");
 captured=dut.sample_angle; capdir=dut.sample_direction_up; capidx=dut.sample_idx;
 if(!dut.hist_seen[capidx] || !dut.hist_valid[capidx]) $fatal(1,"integrated history");
 // Let a later transaction time out without any echo.
 wait(dut.measure_start); wait(dut.measure_done); repeat(5) cycle;
 if(dut.current_valid || dut.digit_codes[15:0]!==16'haaaa) $fatal(1,"noecho invalid");
 wait(dut.measure_busy); transition(0);
 #2 sw7=0; shutcheck;
 repeat(2000) cycle;
 if(dut.hist_seen!==0 || dut.system_state!==0) $fatal(1,"SW7 state cleanup");
 $display("PASS integration: SW6 both transitions while measuring, cancel/history reset SELF->STANDBY->RUN; real 590-us echo near alarm; noecho; SW7 async all external outputs off; shared timebase"); $finish;
end
initial begin #10000000; $fatal(1,"integration timeout"); end
endmodule
