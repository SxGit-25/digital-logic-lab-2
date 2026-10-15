`timescale 1ns/1ps
module radar_unified_top #(
 parameter integer CLK_HZ=50000000,
 parameter integer SELF_TEST_MS=2000, STANDBY_MS=2000, SLOT_MS=2000,
 parameter integer SETTLE_MS=300, SWITCH_MS=20, CONTINUOUS_STEP_MS=60, FAST_STEP_US=16,
 parameter ENABLE_READBACK=0, KEEP_END_BATCH=1,
 parameter MEASUREMENT_BCD=0, CONTINUOUS_DEGREE_STEP=1,
 parameter MINSKY_F=15, MINSKY_K=7, MINSKY_PHASE_BITS=6,
 parameter MINSKY_PHASE_ADD=15, MINSKY_PHASE_INITIAL=63, MINSKY_MICRO_BASE=2
) (
    input  wire        clk,
    input  wire        sw7,
    input  wire        echo,
    output wire        trig,
    output wire        servo,
    output wire        buzzer,
    output wire [15:0] led,
    output wire        seg_a,
    output wire        seg_b,
    output wire        seg_c,
    output wire        seg_d,
    output wire        seg_e,
    output wire        seg_f,
    output wire        seg_g,
    output wire [7:0]  cat_n,
    output wire [7:0]  matrix_row_n,
    output wire [7:0]  matrix_col_r,
    output wire [7:0]  matrix_col_g,
    input wire sw6,
    inout wire [7:0] lcd_data,
    output wire lcd_rd_n,lcd_wr_n,lcd_a0,lcd_rst_n,lcd_cs_n
);

 wire rst,tick_us,tick_ms,blink_2hz,system_on,mode_continuous;
 wire [1:0] system_state;
 wire [11:0] angle_bcd,sample_angle_bcd,current_distance,distance_mm;
 wire direction_up,sample_direction_up,measure_start,measure_cancel,measure_busy,measure_done;
 wire distance_valid,current_valid,step_event,sample_event,measurement_pending;
 wire [2:0] current_level,h0,h1,h2,h3,h4,matrix_row_idx;
 wire [4:0] hist_valid,hist_seen;
 wire [5:0] radius;
 wire radius_valid,trig_int,servo_int,buzzer_int;
 wire [15:0] distance_bcd,measured_bcd,scan_bcd,led_int;
 wire [31:0] digit_codes;
 wire [23:0] row_colors;
 wire [6:0] seg_bus;
 wire [7:0] cat_int,row_int,col_r_int,col_g_int;
 wire outputs_enabled=sw7 && system_on && system_state!=0;
 reset_ctrl u_reset(clk,rst);
 timebase #(.CLK_HZ(CLK_HZ)) u_timebase(clk,rst,tick_us,tick_ms,blink_2hz);
 switch_filter #(.FILTER_MS(SWITCH_MS)) u_switch(clk,rst,tick_ms,sw7,system_on);
 switch_filter #(.FILTER_MS(SWITCH_MS)) u_mode(clk,rst,tick_ms,sw6,mode_continuous);
 generate if(MEASUREMENT_BCD) begin:g_bcd_measurement
 ultrasonic_bcd_budget #(.ENABLE_RADIUS(1)) u_ultrasonic(
  .clk(clk),.rst(rst),.tick_us(tick_us),.measure_start(measure_start),.cancel(measure_cancel),
  .tick_ms(tick_ms),.echo_async(echo),.trig(trig_int),.measure_busy(measure_busy),.measure_done(measure_done),
  .distance_bcd(measured_bcd),.distance_valid(distance_valid),.radius(radius),.radius_valid(radius_valid));
 assign distance_mm=0;
 end else begin:g_binary_measurement
 ultrasonic #(.ENABLE_RADIUS(1)) u_ultrasonic(
  .clk(clk),.rst(rst),.tick_us(tick_us),.measure_start(measure_start),.cancel(measure_cancel),
  .echo_async(echo),.trig(trig_int),.measure_busy(measure_busy),.measure_done(measure_done),
  .distance_mm(distance_mm),.distance_valid(distance_valid),.radius(radius),.radius_valid(radius_valid));
 assign measured_bcd=0;
 end endgenerate
 radar_unified_scan #(.SELF_TEST_MS(SELF_TEST_MS),.STANDBY_MS(STANDBY_MS),.SLOT_MS(SLOT_MS),
  .SETTLE_MS(SETTLE_MS),.CONTINUOUS_STEP_MS(CONTINUOUS_STEP_MS),.FAST_STEP_US(FAST_STEP_US),.HOLD_FAST_PWM(1),.CONTINUOUS_DEGREE_STEP(CONTINUOUS_DEGREE_STEP),.DISTANCE_IS_BCD(MEASUREMENT_BCD)) scan(
  .clk(clk),.rst(rst),.tick_us(tick_us),.tick_ms(tick_ms),.enable(system_on),.continuous_mode(mode_continuous),
  .measure_busy(measure_busy),.measure_done(measure_done),.distance_mm(distance_mm),.distance_valid(distance_valid),.distance_bcd(measured_bcd),.current_bcd(scan_bcd),
  .system_state(system_state),.servo(servo_int),.angle_bcd(angle_bcd),.direction_up(direction_up),
  .measure_start(measure_start),.measure_cancel(measure_cancel),.sample_angle_bcd(sample_angle_bcd),
  .sample_direction_up(sample_direction_up),.current_distance(current_distance),.current_valid(current_valid),
  .current_level(current_level),.hist_level0(h0),.hist_level1(h1),.hist_level2(h2),.hist_level3(h3),.hist_level4(h4),
  .hist_valid(hist_valid),.hist_seen(hist_seen),.step_event(step_event),.sample_event(sample_event),.measurement_pending(measurement_pending));
 generate if(MEASUREMENT_BCD) begin:g_bcd_display
 assign distance_bcd=measured_bcd;
 end else begin:g_binary_display
 bin12_to_bcd u_bcd(clk,rst,current_distance,distance_bcd);
 end endgenerate
 display_compose #(.SUPPORT_CONTINUOUS(1)) u_compose(
  .system_state(system_state),.blink_2hz(blink_2hz),.angle_idx(3'd0),.distance_bcd(distance_bcd),
  .current_valid(current_valid),.hist_level0(h0),.hist_level1(h1),.hist_level2(h2),.hist_level3(h3),.hist_level4(h4),
  .hist_valid(hist_valid),.hist_seen(hist_seen),.row_idx(matrix_row_idx),.digit_codes(digit_codes),.row_colors(row_colors),
  .continuous_mode(1'b1),.continuous_angle_bcd(angle_bcd));
 seg_scan u_seg(clk,rst,tick_us,outputs_enabled,digit_codes,seg_bus,cat_int);
 matrix_scan u_matrix(clk,rst,tick_us,outputs_enabled,row_colors,matrix_row_idx,row_int,col_r_int,col_g_int);
 alarm_ctrl u_alarm(clk,rst,tick_us,tick_ms,blink_2hz,system_state,current_valid,current_level,led_int,buzzer_int);
    assign trig   = outputs_enabled ? trig_int   : 1'b0;
    assign servo  = outputs_enabled ? servo_int  : 1'b0;
    assign buzzer = outputs_enabled ? buzzer_int : 1'b0;
    assign led    = outputs_enabled ? led_int    : 16'h0000;

    assign seg_a = outputs_enabled ? seg_bus[6] : 1'b0;
    assign seg_b = outputs_enabled ? seg_bus[5] : 1'b0;
    assign seg_c = outputs_enabled ? seg_bus[4] : 1'b0;
    assign seg_d = outputs_enabled ? seg_bus[3] : 1'b0;
    assign seg_e = outputs_enabled ? seg_bus[2] : 1'b0;
    assign seg_f = outputs_enabled ? seg_bus[1] : 1'b0;
    assign seg_g = outputs_enabled ? seg_bus[0] : 1'b0;
    assign cat_n = outputs_enabled ? cat_int : 8'hFF;

    assign matrix_row_n = outputs_enabled ? row_int   : 8'hFF;
    assign matrix_col_r = outputs_enabled ? col_r_int : 8'h00;
    assign matrix_col_g = outputs_enabled ? col_g_int : 8'h00;

 wire initialized,bus_ready,bus_done,init_request,init_a0,draw_request,draw_read,draw_a0,oe;
 wire [7:0] init_data,draw_data,read_data,data_out;
 wire [7:0] dropped;
 wire lcd_reset=rst || !system_on || system_state==0;
 radar_lcd_micro #(.ENABLE_READBACK(ENABLE_READBACK),.KEEP_END_BATCH(KEEP_END_BATCH),
  .FRACTION_BITS(MINSKY_F),.ROT_SHIFT(MINSKY_K),.PHASE_BITS(MINSKY_PHASE_BITS),.PHASE_ADD(MINSKY_PHASE_ADD),
  .PHASE_INITIAL(MINSKY_PHASE_INITIAL),.MICRO_BASE(MINSKY_MICRO_BASE)) draw(
  .clk(clk),.rst(lcd_reset),.tick_ms(tick_ms),.initialized(initialized),.lcd_rst_n(lcd_rst_n),
  .request((sample_event || (step_event && !measurement_pending)) && initialized && system_state==3 && sw7),
  .angle_bcd(sample_event ? sample_angle_bcd : angle_bcd),
  .direction_up(sample_event ? sample_direction_up : direction_up),
  .radius(radius),.radius_valid(sample_event && radius_valid),.dropped(dropped),
  .bus_request(draw_request),.bus_read_op(draw_read),.bus_data_op(draw_a0),.bus_write_data(draw_data),
  .bus_ready(bus_ready),.bus_done(bus_done),.bus_read_data(read_data));
 lcd_bus_phase #(.ENABLE_READBACK(ENABLE_READBACK)) bus(
  .clk(clk),.rst(lcd_reset),.request(draw_request),
  .read_op(draw_read),.data_op(draw_a0),
  .write_data(draw_data),.data_in(lcd_data),
  .data_out(data_out),.data_oe(oe),.ready(bus_ready),.done(bus_done),.read_data(read_data),
  .lcd_rd_n(lcd_rd_n),.lcd_wr_n(lcd_wr_n),.lcd_a0(lcd_a0),.lcd_cs_n(lcd_cs_n));
 assign lcd_data=oe ? data_out : 8'bz;
endmodule
