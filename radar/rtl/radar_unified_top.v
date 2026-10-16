`timescale 1ns/1ps
module radar_unified_top #(
 parameter integer CLK_HZ=50000000,
 parameter integer SELF_TEST_MS=2000, STANDBY_MS=2000, SLOT_MS=2000,
 parameter integer SETTLE_MS=300, SWITCH_MS=20, CONTINUOUS_STEP_MS=60, FAST_STEP_US=16,
 parameter ENABLE_READBACK=0, KEEP_END_BATCH=1, SETTLE_FROM_PWM=0,
 parameter P5_UFM=0,
 parameter P5_INVERT=0,
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

 wire rst,tick_us,tick_ms,blink_2hz,system_on,mode_continuous,sw7_sync;
 wire tick_250us,tick_20ms,tick_switch,carrier_2khz,window_50ms;
 wire [2:0] rhythm_phase;
 wire [14:0] global_frame_us;
 wire [1:0] color_phase;
 wire [2:0] display_index;
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
 wire outputs_enabled=sw7_sync && system_on && system_state!=0;
 reset_ctrl u_reset(clk,rst);
 radar_global_timebase_alarm #(.CLK_HZ(CLK_HZ),.SWITCH_SAMPLE_MS(SWITCH_MS)) u_timebase(
 .clk(clk),.rst(rst),.tick_us(tick_us),.tick_ms(tick_ms),.blink_2hz(blink_2hz),
 .tick_250us(tick_250us),.tick_20ms(tick_20ms),.tick_switch(tick_switch),.window_50ms(window_50ms),.rhythm_phase(rhythm_phase),.frame_us(global_frame_us),
 .display_index(display_index),.color_phase(color_phase),.carrier_2khz(carrier_2khz));
 switch_pair_sampled u_switch_pair(.clk(clk),.rst(rst),.sample_tick(tick_switch),
 .sw6(sw6),.sw7(sw7),.mode_continuous(mode_continuous),.system_on(system_on),.sw7_sync(sw7_sync));
 generate if(MEASUREMENT_BCD) begin:g_bcd_measurement
 ultrasonic_bcd_budget_compact #(.ENABLE_RADIUS(1)) u_ultrasonic(
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
  .SETTLE_MS(SETTLE_MS),.SETTLE_FROM_PWM(SETTLE_FROM_PWM),.CONTINUOUS_STEP_MS(CONTINUOUS_STEP_MS),.FAST_STEP_US(FAST_STEP_US),.HOLD_FAST_PWM(1),.CONTINUOUS_DEGREE_STEP(CONTINUOUS_DEGREE_STEP),.DISTANCE_IS_BCD(MEASUREMENT_BCD),.USE_GLOBAL_TIMING(1)) scan(
  .global_frame_us(global_frame_us),.global_frame_tick(tick_20ms),
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
 radar_display_gated u_display(
 .clk(clk),.rst(rst),.enable(outputs_enabled),.tick_250us(tick_250us),.color_phase(color_phase),
 .system_state(system_state),.blink_2hz(blink_2hz),.angle_bcd(angle_bcd),.current_distance_bcd(distance_bcd),
 .current_valid(current_valid),.hist_level0(h0),.hist_level1(h1),.hist_level2(h2),.hist_level3(h3),.hist_level4(h4),
 .hist_valid(hist_valid),.hist_seen(hist_seen),.seg(seg_bus),.cat_n(cat_int),.row_n(row_int),
 .col_r(col_r_int),.col_g(col_g_int),.scan_idx(display_index));
 alarm_global u_alarm(.enable(outputs_enabled),.blink_2hz(blink_2hz),.carrier_2khz(carrier_2khz),
 .window_50ms(window_50ms),.rhythm_phase(rhythm_phase),.system_state(system_state),
 .current_valid(current_valid),.current_level(current_level),.leds(led_int),.buzzer(buzzer_int));
    assign trig   = outputs_enabled ? trig_int   : 1'b0;
    assign servo  = outputs_enabled ? servo_int  : 1'b0;
    assign buzzer = buzzer_int;
    assign led = led_int;

    assign seg_a = seg_bus[6];
    assign seg_b = seg_bus[5];
    assign seg_c = seg_bus[4];
    assign seg_d = seg_bus[3];
    assign seg_e = seg_bus[2];
    assign seg_f = seg_bus[1];
    assign seg_g = seg_bus[0];
    assign cat_n = cat_int;

    assign matrix_row_n = row_int;
    assign matrix_col_r = col_r_int;
    assign matrix_col_g = col_g_int;

 wire initialized,bus_ready,bus_done,init_request,init_a0,draw_request,draw_read,draw_a0,oe;
 wire [7:0] init_data,draw_data,read_data,data_out;
 wire [7:0] dropped;
 wire lcd_reset=rst || !system_on || system_state==0;
 radar_lcd_micro #(.ENABLE_READBACK(ENABLE_READBACK),.KEEP_END_BATCH(KEEP_END_BATCH),.P5_FIXES(1),.P5_UFM(P5_UFM),.P5_INVERT(P5_INVERT),
  .FRACTION_BITS(MINSKY_F),.ROT_SHIFT(MINSKY_K),.PHASE_BITS(MINSKY_PHASE_BITS),.PHASE_ADD(MINSKY_PHASE_ADD),
  .PHASE_INITIAL(MINSKY_PHASE_INITIAL),.MICRO_BASE(MINSKY_MICRO_BASE)) draw(
  .clk(clk),.rst(lcd_reset),.tick_ms(tick_ms),.initialized(initialized),.lcd_rst_n(lcd_rst_n),
  .request((sample_event || (step_event && !measurement_pending)) && initialized && system_state==3 && sw7_sync),
  .continuous_mode(mode_continuous),
  .alarm_active(outputs_enabled && system_state==3 && current_valid && current_level==5),.inverse_phase(blink_2hz),
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
