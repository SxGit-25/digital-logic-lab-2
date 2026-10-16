`timescale 1ns/1ps
// Real top/switch synchronizers/debounce/scan/core/bus. No force/deposit and
// no injected request events. Accelerated scheduling is not throughput data.
module tb_top_quiesce;
 reg clk=0,sw7=1,sw6=1,echo=0;
 wire trig,servo,buzzer,seg_a,seg_b,seg_c,seg_d,seg_e,seg_f,seg_g;
 wire [15:0] led;
 wire [7:0] cat_n,matrix_row_n,matrix_col_r,matrix_col_g;
 wire [7:0] lcd_data;
 wire lcd_rd_n,lcd_wr_n,lcd_a0,lcd_rst_n,lcd_cs_n;
 always #10 clk=~clk;
 radar_unified_top #(.CLK_HZ(1000000),.SELF_TEST_MS(1),.STANDBY_MS(1),
  .SLOT_MS(1000),.SETTLE_MS(1),.SWITCH_MS(1),.CONTINUOUS_STEP_MS(1000),
  .FAST_STEP_US(500000),.ENABLE_READBACK(1),.MEASUREMENT_BCD(1),
  .P5_UFM(1),.P5_UFM_BYTE(1),.P5_INVERT(1),.P5_BEAM(1)) dut(.*);
 // Pin-level constant read responder; pixel-RAM correctness is checked in
 // the separate reference-model tests. This test covers control ordering.
 assign lcd_data=(!dut.oe && !lcd_rd_n && !lcd_cs_n) ? 8'h00 : 8'bz;
 integer cycle=0,case_number=0,passed=0,zero_cycles=0,removals=0;
 integer raw_cycle=0,stop_cycle=0,remove_cycle=0,reset_cycle=0;
 integer gated_cycles=0,early_gates=0;
 reg active=0,expect_busy=0,expect_mode=0;
 reg stop_seen=0,remove_seen=0,reset_seen=0;
 reg before_beam_valid=0;
 always @(posedge clk)begin
  cycle=cycle+1;
  if(active && dut.draw.beam_remove_done)begin
   remove_seen=1;removals=removals+1;remove_cycle=cycle;
  end
  #1;
  if(!dut.rst && !dut.sw7_sync)begin
   if(trig!==0 || servo!==0 || buzzer!==0 || led!==0 ||
      {seg_a,seg_b,seg_c,seg_d,seg_e,seg_f,seg_g}!==0 ||
      cat_n!==8'hff || matrix_row_n!==8'hff || matrix_col_r!==0 || matrix_col_g!==0)
       $fatal(1,"SW7 synchronized immediate output gating failed");
   gated_cycles=gated_cycles+1;
   if(active && !expect_mode && dut.system_on)early_gates=early_gates+1;
  end
  if(active && !reset_seen)begin
   if(dut.system_state==0)zero_cycles=zero_cycles+1;
   if(dut.lcd_stop && !stop_seen)begin
    stop_seen=1;stop_cycle=cycle;before_beam_valid=dut.draw.beam_valid;
    if(expect_busy)begin
     if(!(dut.draw.beam_task && dut.draw.flush_left[0]))
       $fatal(1,"case%0d stop did not arrive during new-line drawing",case_number);
    end else if(!(dut.draw.state==0 && dut.draw.beam_valid))
       $fatal(1,"case%0d stop did not arrive with idle visible line",case_number);
   end
   if(stop_seen && cycle>stop_cycle && !dut.lcd_reset && !dut.lcd_restart_pending)
    $fatal(1,"case%0d one-clock restart lost before withdrawal",case_number);
   if(stop_seen && !remove_seen && dut.lcd_reset)
    $fatal(1,"case%0d LCD reset preceded beam_remove_done",case_number);
  end
 end
 always @(posedge dut.lcd_reset)if(active && !dut.rst)begin
  // Quiescent is reached only after all completed LCD transactions and after
  // the old/new beam has actually been withdrawn by the shared drawing FSM.
  if(!remove_seen || dut.draw.beam_valid!==0 || dut.draw_quiescent!==1 ||
     dut.draw.state!==0 || dut.bus_ready!==1 || dut.draw_request!==0 ||
     lcd_rd_n!==1 || lcd_wr_n!==1 || lcd_cs_n!==1)
    $fatal(1,"case%0d unsafe LCD reset valid=%b state=%d ready=%b",case_number,dut.draw.beam_valid,dut.draw.state,dut.bus_ready);
  reset_seen=1;reset_cycle=cycle;
 end
 task wait_idle_line;
  begin
   wait(dut.initialized && dut.system_state==3);
   wait(dut.draw.state==0 && dut.draw.beam_valid && !dut.draw.pending);
   @(negedge clk);
   if(!(dut.draw.state==0 && dut.draw.beam_valid))$fatal(1,"idle window lost");
  end
 endtask
 task wait_drawing_line;
  begin
   wait(dut.initialized && dut.system_state==3);
   wait(dut.draw.beam_task && dut.draw.flush_left[0] && dut.draw.state==5);
   @(negedge clk);
  end
 endtask
 task arm_case;
  input is_mode,is_busy;
  begin
   case_number=case_number+1;expect_mode=is_mode;expect_busy=is_busy;
   stop_seen=0;remove_seen=0;reset_seen=0;zero_cycles=0;removals=0;
   early_gates=0;raw_cycle=cycle;stop_cycle=0;remove_cycle=0;reset_cycle=0;
   active=1;
   if(is_mode)sw6=!sw6;else sw7=0;
  end
 endtask
 task finish_case;
  begin
   wait(reset_seen);@(negedge clk);
   if(!stop_seen || !remove_seen || removals!=1 || reset_cycle<=stop_cycle || remove_cycle<=stop_cycle)
    $fatal(1,"case%0d stop/remove/reset coverage",case_number);
   if(expect_mode && zero_cycles!=1)$fatal(1,"case%0d mode OFF pulse width=%0d (expected one clock)",case_number,zero_cycles);
   if(!expect_mode && early_gates==0)$fatal(1,"SW7 outputs did not gate before debounce");
   $display("PASS quiesce case=%0d mode=%0d busy_draw=%0d raw=%0d stop=%0d remove_done=%0d reset=%0d state0_clocks=%0d restart_latched=1 immediate_off_cycles=%0d",case_number,expect_mode,expect_busy,raw_cycle,stop_cycle,remove_cycle,reset_cycle,zero_cycles,early_gates);
   passed=passed+1;active=0;
  end
 endtask
 initial begin
  wait(!dut.rst);wait(dut.system_on && dut.mode_continuous);
  wait_idle_line;arm_case(1,0);finish_case;
  wait(!dut.lcd_reset && dut.initialized && !dut.mode_continuous);
  wait_drawing_line;arm_case(1,1);finish_case;
  wait(!dut.lcd_reset && dut.initialized && dut.mode_continuous);
  wait_idle_line;arm_case(0,0);finish_case;
  repeat(5000)@(negedge clk);sw7=1;
  wait(dut.system_on && !dut.lcd_reset);
  wait_drawing_line;arm_case(0,1);finish_case;
  if(passed!=4 || gated_cycles==0)$fatal(1,"coverage count");
  $display("PASS real-top quiesce all four cases; source byte_a_source; no force/deposit; accelerated timers only, not a throughput measurement");
  $finish;
 end
 initial begin #300000000;$fatal(1,"quiesce watchdog case=%0d state=%d draw=%d beam=%b init=%b",case_number,dut.system_state,dut.draw.state,dut.draw.beam_valid,dut.initialized);end
endmodule
