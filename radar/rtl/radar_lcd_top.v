`timescale 1ns/1ps

module radar_lcd_top #(
    parameter integer CLK_HZ       = 50_000_000,
    parameter integer SELF_TEST_MS = 2000,
    parameter integer STANDBY_MS   = 2000,
    parameter integer SLOT_MS      = 2000,
    parameter integer SETTLE_MS    = 300,
    parameter integer SWITCH_MS    = 20,
    parameter integer CONTINUOUS_SAMPLE_MS = 60,
    parameter ENABLE_READBACK=0,
    parameter USE_UFM=1,
    parameter FRACTION_BITS=8,
    parameter MIRROR_X=0,
    parameter [5:0] MIN_RADIUS=6,
    parameter integer LCD_RESET_CYCLES=50000,
    parameter integer LCD_WAIT_CYCLES=1000000,
    parameter SERIAL_ACCUMULATE=0,
    parameter integer LCD_WAIT_TICK_CYCLES=LCD_RESET_CYCLES>=CLK_HZ/1000 ? CLK_HZ/1000 : 1
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
    wire rst;
    wire mode_continuous;
    reg previous_mode;
    wire mode_changed = previous_mode != mode_continuous;
    wire mode_rst = rst || mode_changed;
    wire [7:0] continuous_angle;
    wire [11:0] continuous_angle_bcd;
    wire continuous_direction_up;
    wire continuous_frame_start;
    wire [7:0] sample_angle;
    wire sample_direction_up;
    always @(posedge clk) begin
        if (rst) previous_mode <= 1'b0;
        else previous_mode <= mode_continuous;
    end
    wire tick_us;
    wire tick_ms;
    wire blink_2hz;
    wire system_on;
    wire [1:0] system_state;
    wire servo_enable;
    wire [2:0] angle_idx;
    wire angle_applied;
    wire measure_start;
    wire measure_cancel;
    wire measure_busy;
    wire measure_done;
    wire [11:0] distance_mm;
    wire distance_valid;
    wire [2:0] sample_idx;
    wire [11:0] current_distance;
    wire current_valid;
    wire [2:0] current_level;
    wire [2:0] hist_level0;
    wire [2:0] hist_level1;
    wire [2:0] hist_level2;
    wire [2:0] hist_level3;
    wire [2:0] hist_level4;
    wire [4:0] hist_valid;
    wire [4:0] hist_seen;
    wire [31:0] digit_codes;
    wire [15:0] distance_bcd;
    wire [2:0] matrix_row_idx;
    wire [23:0] row_colors;
    wire [6:0] seg_bus;
    wire [7:0] cat_int;
    wire [7:0] row_int;
    wire [7:0] col_r_int;
    wire [7:0] col_g_int;
    wire [15:0] led_int;
    wire buzzer_int;
    wire servo_int;
    wire trig_int;
    wire outputs_enabled = sw7 && system_on && (system_state != 2'd0);

    switch_filter #(.FILTER_MS(SWITCH_MS)) u_mode_switch (
        .clk(clk), .rst(rst), .tick_ms(tick_ms), .sw_raw(sw6),
        .system_on(mode_continuous)
    );

    reset_ctrl u_reset (
        .clk(clk), .rst(rst)
    );

    timebase #(.CLK_HZ(CLK_HZ)) u_timebase (
        .clk(clk), .rst(rst), .tick_us(tick_us), .tick_ms(tick_ms),
        .blink_2hz(blink_2hz)
    );

    switch_filter #(.FILTER_MS(SWITCH_MS)) u_switch (
        .clk(clk), .rst(rst), .tick_ms(tick_ms), .sw_raw(sw7),
        .system_on(system_on)
    );

    servo_pwm #(.SUPPORT_CONTINUOUS(1)) u_servo (
        .clk(clk), .rst(mode_rst), .tick_us(tick_us), .enable(servo_enable),
        .angle_idx(angle_idx), .servo_out(servo_int),
        .angle_applied(angle_applied),
        .continuous_mode(mode_continuous), .sweep_run(system_state == 2'd3),
        .continuous_angle(continuous_angle), .continuous_angle_bcd(continuous_angle_bcd),
        .direction_up(continuous_direction_up), .frame_start(continuous_frame_start)
    );

    wire [5:0] radius;
    wire radius_valid;
    ultrasonic #(.ENABLE_RADIUS(1)) u_ultrasonic (
        .clk(clk), .rst(rst), .tick_us(tick_us),
        .measure_start(measure_start), .cancel(measure_cancel || mode_changed),
        .echo_async(echo), .trig(trig_int), .measure_busy(measure_busy),
        .measure_done(measure_done), .distance_mm(distance_mm),
        .distance_valid(distance_valid),.radius(radius),.radius_valid(radius_valid)
    );

    radar_ctrl #(
        .SELF_TEST_MS(SELF_TEST_MS), .STANDBY_MS(STANDBY_MS),
        .SLOT_MS(SLOT_MS), .SETTLE_MS(SETTLE_MS),
        .SUPPORT_CONTINUOUS(1), .CONTINUOUS_SAMPLE_MS(CONTINUOUS_SAMPLE_MS)
    ) u_control (
        .clk(clk), .rst(mode_rst), .tick_ms(tick_ms), .system_on(system_on),
        .angle_applied(angle_applied), .measure_busy(measure_busy),
        .measure_done(measure_done), .distance_mm(distance_mm),
        .distance_valid(distance_valid), .system_state(system_state),
        .servo_enable(servo_enable), .angle_idx(angle_idx),
        .measure_start(measure_start), .measure_cancel(measure_cancel),
        .sample_idx(sample_idx), .current_distance(current_distance),
        .current_valid(current_valid), .current_level(current_level),
        .hist_level0(hist_level0), .hist_level1(hist_level1),
        .hist_level2(hist_level2), .hist_level3(hist_level3),
        .hist_level4(hist_level4), .hist_valid(hist_valid),
        .hist_seen(hist_seen), .continuous_mode(mode_continuous),
        .continuous_angle(continuous_angle), .continuous_direction_up(continuous_direction_up),
        .sample_angle(sample_angle), .sample_direction_up(sample_direction_up)
    );

    bin12_to_bcd u_bcd (
        .clk(clk), .rst(rst), .binary(current_distance),
        .bcd(distance_bcd)
    );

    display_compose #(.SUPPORT_CONTINUOUS(1)) u_compose (
        .system_state(system_state), .blink_2hz(blink_2hz),
        .angle_idx(angle_idx), .distance_bcd(distance_bcd),
        .current_valid(current_valid), .hist_level0(hist_level0),
        .hist_level1(hist_level1), .hist_level2(hist_level2),
        .hist_level3(hist_level3), .hist_level4(hist_level4),
        .hist_valid(hist_valid), .hist_seen(hist_seen),
        .row_idx(matrix_row_idx), .digit_codes(digit_codes),
        .row_colors(row_colors), .continuous_mode(mode_continuous),
        .continuous_angle_bcd(continuous_angle_bcd)
    );

    seg_scan u_seg (
        .clk(clk), .rst(rst), .tick_us(tick_us),
        .enable(outputs_enabled), .digit_codes(digit_codes),
        .seg(seg_bus), .cat_n(cat_int)
    );

    matrix_scan u_matrix (
        .clk(clk), .rst(rst), .tick_us(tick_us),
        .enable(outputs_enabled), .row_colors(row_colors),
        .row_idx(matrix_row_idx), .row_n(row_int),
        .col_r(col_r_int), .col_g(col_g_int)
    );

    alarm_ctrl u_alarm (
        .clk(clk), .rst(rst), .tick_us(tick_us), .tick_ms(tick_ms),
        .blink_2hz(blink_2hz), .system_state(system_state),
        .current_valid(current_valid), .current_level(current_level),
        .leds(led_int), .buzzer(buzzer_int)
    );

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
    wire lcd_ready,lcd_done,lcd_initialized,lcd_oe;
    wire [7:0] lcd_data_out,draw_angle;
    wire draw_request,draw_direction,draw_valid,draw_plot_only;
    wire [5:0] draw_radius;
    wire lcd_reset = rst || mode_changed || !system_on;
    assign lcd_data=lcd_oe ? lcd_data_out : 8'bz;
    radar_lcd_bridge lcd_bridge(
        .clk(clk),.rst(lcd_reset),
        .enable(sw7 && system_on && mode_continuous && system_state==2'd3),
        .beam_angle(continuous_angle),.beam_direction_up(continuous_direction_up),
        .measure_start(measure_start && !measure_busy && !measure_cancel),
        .measure_done(measure_done),.sample_angle(sample_angle),.sample_direction_up(sample_direction_up),
        .radius(radius),.radius_valid(radius_valid),.lcd_ready(lcd_ready),.lcd_done(lcd_done),
        .request(draw_request),.angle(draw_angle),.direction_up(draw_direction),
        .draw_radius(draw_radius),.draw_valid(draw_valid),.plot_only(draw_plot_only));
    lcd_p4_core #(.ENABLE_READBACK(ENABLE_READBACK),.USE_UFM(USE_UFM),
        .FRACTION_BITS(FRACTION_BITS),.MIRROR_X(MIRROR_X),.MIN_RADIUS(MIN_RADIUS),
        .RESET_CYCLES(LCD_RESET_CYCLES),.WAIT_CYCLES(LCD_WAIT_CYCLES),.SERIAL_ACCUMULATE(SERIAL_ACCUMULATE),.WAIT_TICK_CYCLES(LCD_WAIT_TICK_CYCLES)) lcd_core(
        .clk(clk),.rst(lcd_reset),.delay_tick(tick_ms),.request(draw_request),.plot_only(draw_plot_only),
        .angle(draw_angle),.direction_up(draw_direction),.radius(draw_radius),.radius_valid(draw_valid),
        .ready(lcd_ready),.done(lcd_done),.initialized(lcd_initialized),
        .data_in(lcd_data),.data_out(lcd_data_out),.data_oe(lcd_oe),
        .lcd_rd_n(lcd_rd_n),.lcd_wr_n(lcd_wr_n),.lcd_a0(lcd_a0),.lcd_rst_n(lcd_rst_n),.lcd_cs_n(lcd_cs_n));
endmodule
