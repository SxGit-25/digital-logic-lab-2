`timescale 1ns/1ps

module radar_top #(
    parameter integer CLK_HZ       = 50_000_000,
    parameter integer SELF_TEST_MS = 2000,
    parameter integer STANDBY_MS   = 2000,
    parameter integer SLOT_MS      = 2000,
    parameter integer SETTLE_MS    = 300,
    parameter integer SWITCH_MS    = 20
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
    output wire [7:0]  matrix_col_g
);
    wire rst;
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

    servo_pwm u_servo (
        .clk(clk), .rst(rst), .tick_us(tick_us), .enable(servo_enable),
        .angle_idx(angle_idx), .servo_out(servo_int),
        .angle_applied(angle_applied)
    );

    ultrasonic u_ultrasonic (
        .clk(clk), .rst(rst), .tick_us(tick_us),
        .measure_start(measure_start), .cancel(measure_cancel),
        .echo_async(echo), .trig(trig_int), .measure_busy(measure_busy),
        .measure_done(measure_done), .distance_mm(distance_mm),
        .distance_valid(distance_valid)
    );

    radar_ctrl #(
        .SELF_TEST_MS(SELF_TEST_MS), .STANDBY_MS(STANDBY_MS),
        .SLOT_MS(SLOT_MS), .SETTLE_MS(SETTLE_MS)
    ) u_control (
        .clk(clk), .rst(rst), .tick_ms(tick_ms), .system_on(system_on),
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
        .hist_seen(hist_seen)
    );

    display_compose u_compose (
        .system_state(system_state), .blink_2hz(blink_2hz),
        .angle_idx(angle_idx), .current_distance(current_distance),
        .current_valid(current_valid), .hist_level0(hist_level0),
        .hist_level1(hist_level1), .hist_level2(hist_level2),
        .hist_level3(hist_level3), .hist_level4(hist_level4),
        .hist_valid(hist_valid), .hist_seen(hist_seen),
        .row_idx(matrix_row_idx), .digit_codes(digit_codes),
        .row_colors(row_colors)
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
endmodule
