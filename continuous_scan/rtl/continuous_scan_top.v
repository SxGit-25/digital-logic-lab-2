`timescale 1ns/1ps

module continuous_scan_top #(
    parameter integer CLK_HZ = 50_000_000,
    parameter integer SWITCH_MS = 20,
    parameter integer STEP_US = 5,
    parameter integer STARTUP_FRAMES = 50
) (
    input wire clk,
    input wire sw7,
    output wire trig,
    output wire servo,
    output wire buzzer,
    output wire [15:0] led,
    output wire seg_a, seg_b, seg_c, seg_d, seg_e, seg_f, seg_g,
    output wire [7:0] cat_n,
    output wire [7:0] matrix_row_n,
    output wire [7:0] matrix_col_r,
    output wire [7:0] matrix_col_g
);
    wire rst, tick_us, tick_ms, system_on;
    wire direction_up;
    wire [11:0] active_pulse_us;
    wire enabled = sw7 && system_on && !rst;

    reset_ctrl u_reset (.clk(clk), .rst(rst));
    timebase #(.CLK_HZ(CLK_HZ)) u_timebase (
        .clk(clk), .rst(rst), .tick_us(tick_us), .tick_ms(tick_ms), .blink_2hz()
    );
    switch_filter #(.FILTER_MS(SWITCH_MS)) u_switch (
        .clk(clk), .rst(rst), .tick_ms(tick_ms), .sw_raw(sw7), .system_on(system_on)
    );
    servo_sweep #(.STEP_US(STEP_US), .STARTUP_FRAMES(STARTUP_FRAMES)) u_sweep (
        .clk(clk), .rst(rst), .tick_us(tick_us), .enable(enabled),
        .servo_out(servo), .active_pulse_us(active_pulse_us),
        .direction_up(direction_up), .frame_start()
    );

    // Diagnostic LEDs: enabled, increasing command, decreasing command.
    assign led = enabled ? (direction_up ? 16'h0003 : 16'h0005) : 16'h0000;
    assign trig = 1'b0;
    assign buzzer = 1'b0;
    assign {seg_a,seg_b,seg_c,seg_d,seg_e,seg_f,seg_g} = 7'b0;
    assign cat_n = 8'hFF;
    assign matrix_row_n = 8'hFF;
    assign matrix_col_r = 8'h00;
    assign matrix_col_g = 8'h00;
endmodule
