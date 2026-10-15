`timescale 1ns/1ps
module tb_budget_top;
 reg clk=0,sw7=0,sw6=0,echo=0;
 always #10 clk=~clk;
 wire [57:0] pins0,pins1;
 wire [7:0] lcd0,lcd1;
 wire rd0,wr0,a00,res0,cs0,rd1,wr1,a01,res1,cs1;
 radar_unified_top #(.MEASUREMENT_BCD(1),.CLK_HZ(1000000),.SELF_TEST_MS(2),.STANDBY_MS(2),
 .SLOT_MS(100),.SETTLE_MS(50),.SWITCH_MS(1),.CONTINUOUS_STEP_MS(60),.FAST_STEP_US(1)) safe(
 .clk(clk),.sw7(sw7),.sw6(sw6),.echo(echo),.trig(pins0[57]),.servo(pins0[56]),.buzzer(pins0[55]),
 .led(pins0[54:39]),.seg_a(pins0[38]),.seg_b(pins0[37]),.seg_c(pins0[36]),.seg_d(pins0[35]),
 .seg_e(pins0[34]),.seg_f(pins0[33]),.seg_g(pins0[32]),.cat_n(pins0[31:24]),
 .matrix_row_n(pins0[23:16]),.matrix_col_r(pins0[15:8]),.matrix_col_g(pins0[7:0]),
 .lcd_data(lcd0),.lcd_rd_n(rd0),.lcd_wr_n(wr0),.lcd_a0(a00),.lcd_rst_n(res0),.lcd_cs_n(cs0));
 radar_unified_top #(.ENABLE_READBACK(1),.MEASUREMENT_BCD(1),.CLK_HZ(1000000),.SELF_TEST_MS(2),.STANDBY_MS(2),
 .SLOT_MS(100),.SETTLE_MS(50),.SWITCH_MS(1),.CONTINUOUS_STEP_MS(60),.FAST_STEP_US(1)) readback(
 .clk(clk),.sw7(sw7),.sw6(sw6),.echo(echo),.trig(pins1[57]),.servo(pins1[56]),.buzzer(pins1[55]),
 .led(pins1[54:39]),.seg_a(pins1[38]),.seg_b(pins1[37]),.seg_c(pins1[36]),.seg_d(pins1[35]),
 .seg_e(pins1[34]),.seg_f(pins1[33]),.seg_g(pins1[32]),.cat_n(pins1[31:24]),
 .matrix_row_n(pins1[23:16]),.matrix_col_r(pins1[15:8]),.matrix_col_g(pins1[7:0]),
 .lcd_data(lcd1),.lcd_rd_n(rd1),.lcd_wr_n(wr1),.lcd_a0(a01),.lcd_rst_n(res1),.lcd_cs_n(cs1));
 st7565_model model0(res0,cs0,rd0,wr0,a00,safe.oe,lcd0);
 st7565_model model1(res1,cs1,rd1,wr1,a01,readback.oe,lcd1);
 integer cycles=0,shots=0,basic_samples=0,continuous_samples=0,expected_drops=0;
 integer basic_targets=0,continuous_targets=0,basic_drops=0,continuous_drops=0;
 integer echo_length=29400,mode_resets=0,reads_before;
 reg [11:0] accepted_angle;
 reg accepted_direction;
 always @(posedge pins1[57]) begin
  shots=shots+1;
  @(negedge pins1[57]);
  repeat(50) @(negedge clk);
  echo=1;
  repeat(echo_length) @(negedge clk);
  echo=0;
 end
 function [2:0] nearest;
  input [11:0] a;
  begin
   if(a<12'h023) nearest=0;else if(a<12'h068) nearest=1;
   else if(a<12'h113) nearest=2;else if(a<12'h158) nearest=3;else nearest=4;
  end
 endfunction
 always @(posedge clk) begin
  cycles=cycles+1;
  if(readback.lcd_reset || !readback.initialized) expected_drops=0;
  else if((readback.sample_event || (readback.step_event && !readback.measurement_pending)) && readback.system_state==3 && sw7 &&
          readback.draw.state!=0 && expected_drops<255) expected_drops=expected_drops+1;
  if(readback.draw.accept && readback.sample_event) begin
   if(readback.mode_continuous) continuous_targets=continuous_targets+1;
   else basic_targets=basic_targets+1;
  end
  if(readback.measure_start) begin
   accepted_angle=readback.angle_bcd;accepted_direction=readback.direction_up;
  end
  #1;
  if(cycles>20) begin
   if(pins0!==pins1) $fatal(1,"LCD affects radar pins cycle=%0d",cycles);
   if(rd0!==1 || safe.oe!==1 || model0.reads!=0) $fatal(1,"Default readback safety");
   if(readback.draw.dropped!==expected_drops) $fatal(1,"Drop count mismatch got=%0d wanted=%0d",readback.draw.dropped,expected_drops);
   if(readback.measure_start && readback.mode_continuous && readback.scan.fast_busy) $fatal(1,"Continuous fast queue");
   if(readback.sample_event) begin
    if(readback.sample_angle_bcd!==accepted_angle || readback.sample_direction_up!==accepted_direction)
      $fatal(1,"Measurement tag mismatch");
    if(readback.scan.sample_idx!==nearest(accepted_angle)) $fatal(1,"Nearest history lane");
    if(readback.distance_bcd!==readback.measured_bcd || readback.current_valid!==readback.distance_valid)
      $fatal(1,"Distance commit mismatch");
    if(readback.current_valid && readback.current_distance<200 && readback.current_level!=5) $fatal(1,"Alarm level mismatch");
    if(readback.mode_continuous) continuous_samples=continuous_samples+1;
    else basic_samples=basic_samples+1;
   end
  end
 end
 task switch_mode;
  input target_mode;
  begin
   echo_length=5000;
   @(posedge pins1[57]);@(negedge clk);sw6=target_mode;
   wait(readback.system_state==0);#1;
   if(readback.scan.hist_seen!=0 || readback.current_valid || !readback.measure_cancel)
     $fatal(1,"Mode reset history/cancel");
   mode_resets=mode_resets+1;
   wait(readback.system_state==1);echo_length=29400;
   wait(readback.initialized);
  end
 endtask
 initial begin
  repeat(30) @(negedge clk);sw7=1;
  wait(readback.initialized);reads_before=model1.reads;
  repeat(400000) @(negedge clk);
  if(model1.reads<=reads_before || basic_samples==0) $fatal(1,"Basic mode LCD inactive");
  basic_drops=expected_drops;
  switch_mode(1);
  reads_before=model1.reads;repeat(400000) @(negedge clk);
  if(model1.reads<=reads_before || continuous_samples==0) $fatal(1,"Continuous mode LCD inactive");
  continuous_drops=expected_drops;
  if(continuous_drops!=0 || continuous_targets<2 || basic_targets<2) $fatal(1,"Normal samples lost to redundant step drawing");
  switch_mode(0);
  repeat(150000) @(negedge clk);
  #3;sw7=0;#1;
  if(pins0!=={3'b000,16'h0,7'h0,8'hff,8'hff,8'h0,8'h0} || pins1!==pins0)
    $fatal(1,"SW7 asynchronous output gate");
  $display("PASS tb_unified_top cycles=%0d shots=%0d basic_samples=%0d continuous_samples=%0d mode_resets=%0d readback_reads=%0d",cycles,shots,basic_samples,continuous_samples,mode_resets,model1.reads);
  $display("LCD_COUNTS basic_targets=%0d continuous_targets=%0d basic_fast_step_drops=%0d continuous_drops=%0d",basic_targets,continuous_targets,basic_drops,continuous_drops);
  $finish;
 end
 initial begin repeat(10000000) @(negedge clk);$fatal(1,"Top timeout");end
endmodule
