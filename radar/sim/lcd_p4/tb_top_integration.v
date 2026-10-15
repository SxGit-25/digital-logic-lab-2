`timescale 1ns/1ps
// Original pins must remain cycle-identical when the LCD path is added.
module tb_top_integration #(parameter READBACK=0, SERIAL_ACCUMULATE=0);
 reg clk=0,sw7=0,sw6=0,echo=0;
 always #10 clk=~clk;
 wire [57:0] observed,baseline;
 radar_lcd_top #(.CLK_HZ(1000000),.SELF_TEST_MS(1),.STANDBY_MS(1),
  .SLOT_MS(80),.SETTLE_MS(1),.SWITCH_MS(1),.CONTINUOUS_SAMPLE_MS(60),
  .ENABLE_READBACK(READBACK),.USE_UFM(0),.LCD_RESET_CYCLES(10),.LCD_WAIT_CYCLES(20),.SERIAL_ACCUMULATE(SERIAL_ACCUMULATE)) dut(
  .clk(clk),.sw7(sw7),.sw6(sw6),.echo(echo),
  .trig(observed[57]),.servo(observed[56]),.buzzer(observed[55]),.led(observed[54:39]),
  .seg_a(observed[38]),.seg_b(observed[37]),.seg_c(observed[36]),.seg_d(observed[35]),
  .seg_e(observed[34]),.seg_f(observed[33]),.seg_g(observed[32]),.cat_n(observed[31:24]),
  .matrix_row_n(observed[23:16]),.matrix_col_r(observed[15:8]),.matrix_col_g(observed[7:0]));
 radar_mode_legacy #(.CLK_HZ(1000000),.SELF_TEST_MS(1),.STANDBY_MS(1),
  .SLOT_MS(80),.SETTLE_MS(1),.SWITCH_MS(1),.CONTINUOUS_SAMPLE_MS(60)) reference(
  .clk(clk),.sw7(sw7),.sw6(sw6),.echo(echo),
  .trig(baseline[57]),.servo(baseline[56]),.buzzer(baseline[55]),.led(baseline[54:39]),
  .seg_a(baseline[38]),.seg_b(baseline[37]),.seg_c(baseline[36]),.seg_d(baseline[35]),
  .seg_e(baseline[34]),.seg_f(baseline[33]),.seg_g(baseline[32]),.cat_n(baseline[31:24]),
  .matrix_row_n(baseline[23:16]),.matrix_col_r(baseline[15:8]),.matrix_col_g(baseline[7:0]));
 st7565_model model(dut.lcd_rst_n,dut.lcd_cs_n,dut.lcd_rd_n,dut.lcd_wr_n,dut.lcd_a0,dut.lcd_oe,dut.lcd_data);
 // Counters in the shared model are cumulative; begin a new init epoch on panel reset.
 always @(negedge dut.lcd_rst_n) begin #1;model.commands=0;model.clear_writes=0;end
 integer cycles=0,basic_done=0,continuous_done=0,shot=0;
 integer beam_requests=0,target_requests=0,valid_targets=0,invalid_targets=0;
 reg [7:0] accepted_angle=0,result_angle=0;
 reg accepted_direction=1,result_direction=1,result_valid=0;
 reg [5:0] result_radius=0;
 always @(posedge clk) begin
  if(dut.mode_continuous && dut.measure_start && !dut.measure_busy && !dut.measure_cancel) begin
   accepted_angle=dut.continuous_angle;accepted_direction=dut.continuous_direction_up;
  end
  if(dut.mode_continuous && dut.measure_done) begin
   if(dut.sample_angle!==accepted_angle || dut.sample_direction_up!==accepted_direction)
    $fatal(1,"Ultrasonic result is not bound to accepted sample angle/direction");
   result_angle=dut.sample_angle;result_direction=dut.sample_direction_up;
   result_radius=dut.radius;result_valid=dut.radius_valid;
   if(dut.radius_valid && (!dut.distance_valid || dut.distance_mm>1200 || dut.radius!==dut.distance_mm/25))
    $fatal(1,"Integrated radius conversion/validity incorrect");
  end
  if(dut.draw_request && dut.lcd_ready) begin
   if(dut.draw_plot_only) begin
    target_requests=target_requests+1;
    if(dut.draw_valid) valid_targets=valid_targets+1;else invalid_targets=invalid_targets+1;
    if({dut.draw_angle,dut.draw_direction,dut.draw_radius,dut.draw_valid}!==
       {result_angle,result_direction,result_radius,result_valid})
     $fatal(1,"Top LCD target payload lost sample/radius binding");
   end else begin
    beam_requests=beam_requests+1;
    if(dut.draw_valid) $fatal(1,"Live beam carries an ultrasonic target");
   end
  end
  if(!dut.rst && (!sw7 || !dut.mode_continuous) && dut.draw_request)
   $fatal(1,"LCD request survived off/basic mode");
 end
 always @(posedge clk) begin
  #1;cycles=cycles+1;
  if(cycles>20 && observed!==baseline)
   $fatal(1,"Original pin regression cycle=%0d observed=%h baseline=%h",cycles,observed,baseline);
  if(dut.measure_done) begin
   if(dut.mode_continuous) continuous_done=continuous_done+1;
   else basic_done=basic_done+1;
  end
  if(!READBACK && !dut.rst && (!dut.lcd_oe || !dut.lcd_rd_n))
   $fatal(1,"Default readback policy failed");
 end
 initial forever begin
  @(negedge baseline[57]);shot=shot+1;
  if(shot%4!=0) begin
   repeat(80) @(negedge clk);echo=1;
   case(shot%4)
    1:repeat(1180) @(negedge clk);
    2:repeat(5900) @(negedge clk);
    3:repeat(8000) @(negedge clk);
   endcase
   echo=0;
  end
 end
 initial begin
  repeat(30) @(negedge clk);sw7=1;
  repeat(300000) @(negedge clk);sw6=1;
  repeat(500000) @(negedge clk);sw6=0;
  repeat(120000) @(negedge clk);sw7=0;
  repeat(5000) @(negedge clk);
  if(basic_done<3 || continuous_done<5) $fatal(1,"Insufficient baseline coverage basic=%0d continuous=%0d",basic_done,continuous_done);
   if(observed[57:32]!==0 || observed[31:16]!==16'hffff || observed[15:0]!==0)
    $fatal(1,"Off-state outputs not blank");
  if(READBACK && (beam_requests<8 || target_requests<6 || valid_targets<2 || invalid_targets<2 || model.reads==0))
   $fatal(1,"Insufficient enabled LCD coverage beams=%0d targets=%0d valid=%0d invalid=%0d",beam_requests,target_requests,valid_targets,invalid_targets);
  if(!READBACK && (beam_requests || target_requests || model.reads)) $fatal(1,"Default policy drew/read LCD");
  $display("LCD READBACK=%0d beams=%0d targets=%0d valid=%0d invalid=%0d reads=%0d",READBACK,beam_requests,target_requests,valid_targets,invalid_targets,model.reads);
  $display("PASS tb_top_integration cycles=%0d basic_samples=%0d continuous_samples=%0d shots=%0d; ca8ec99 original pins cycle-identical; basic/continuous/mode/off/default readback",cycles,basic_done,continuous_done,shot);
  $finish;
 end
 initial begin #30000000;$fatal(1,"Top integration timeout");end
endmodule



