`timescale 1ns/1ps

module servo_pwm #(
    parameter integer SUPPORT_CONTINUOUS = 0,
    parameter integer USE_5US_UNITS = 1
) (
    input  wire       clk,
    input  wire       rst,
    input  wire       tick_us,
    input  wire       enable,
    input  wire [2:0] angle_idx,
    output wire       servo_out,
    output reg        angle_applied,
    input wire continuous_mode,
    input wire sweep_run,
    output reg [7:0] continuous_angle,
    output reg [11:0] continuous_angle_bcd,
    output reg direction_up,
    output reg frame_start
);
    localparam integer FRAME_WIDTH = USE_5US_UNITS ? 12 : 15;
    localparam integer PULSE_WIDTH = USE_5US_UNITS ? 9 : 12;
    localparam integer FRAME_LAST = USE_5US_UNITS ? 3999 : 19999;
    localparam integer PULSE_MIN = USE_5US_UNITS ? 100 : 500;
    localparam integer PULSE_MAX = USE_5US_UNITS ? 500 : 2500;
    localparam integer PULSE_STEP = USE_5US_UNITS ? 1 : 5;
    reg [FRAME_WIDTH-1:0] frame_count;
    reg [2:0] frame_sub_us;
    reg [2:0]  active_angle;
    reg        was_enabled;
    reg [PULSE_WIDTH-1:0] pulse_units;
    reg [PULSE_WIDTH-1:0] sweep_pulse_units;
    reg [4:0] angle_phase;
    wire continuous_active = SUPPORT_CONTINUOUS && continuous_mode;
    wire [PULSE_WIDTH-1:0] selected_pulse = continuous_active ? sweep_pulse_units : pulse_units;
    wire frame_unit_last = !USE_5US_UNITS || (frame_sub_us == 3'd4);
    wire frame_last = (frame_count == FRAME_LAST) && frame_unit_last;
    // Observation aliases only; production logic compares the unit counters.
    // Shift/add aliases are trimmed when no testbench observes them.
    wire [14:0] frame_us = USE_5US_UNITS ?
        (({3'b000,frame_count} << 2) + frame_count + frame_sub_us) : frame_count;
    wire [11:0] sweep_pulse_us = USE_5US_UNITS ?
        (({3'b000,sweep_pulse_units} << 2) + sweep_pulse_units) : sweep_pulse_units;
    wire degree_step = direction_up ? (angle_phase >= 5'd11) : (angle_phase < 5'd9);
    wire [4:0] phase_delta = direction_up ? (degree_step ? 5'd21 : 5'd9) :
                                                         (degree_step ? 5'd11 : 5'd23);
    wire sweep_endpoint = direction_up ? (sweep_pulse_units == PULSE_MAX-PULSE_STEP) :
                                         (sweep_pulse_units == PULSE_MIN+PULSE_STEP);

    // One shared decimal step datapath for both directions. In the reachable
    // 0..180 range the hundreds digit is one bit, toggled by a decimal carry.
    function [11:0] bcd_step;
        input [11:0] value;
        input up;
        reg [3:0] delta;
        reg [3:0] limit;
        reg [3:0] wrap;
        begin
            delta = up ? 4'd1 : 4'd15;
            limit = up ? 4'd9 : 4'd0;
            wrap = up ? 4'd0 : 4'd9;
            bcd_step = value;
            if (value[3:0] != limit) bcd_step[3:0] = value[3:0] + delta;
            else begin
                bcd_step[3:0] = wrap;
                if (value[7:4] != limit) bcd_step[7:4] = value[7:4] + delta;
                else begin
                    bcd_step[7:4] = wrap;
                    bcd_step[11:8] = {3'b000, !value[8]};
                end
            end
        end
    endfunction

    always @(*) begin
        case (active_angle)
            3'd0: pulse_units = PULSE_MIN;
            3'd1: pulse_units = PULSE_MIN + PULSE_MIN;
            3'd2: pulse_units = PULSE_MIN + PULSE_MIN + PULSE_MIN;
            3'd3: pulse_units = PULSE_MAX - PULSE_MIN;
            3'd4: pulse_units = PULSE_MAX;
            default: pulse_units = PULSE_MIN;
        endcase
    end

    // All widths are multiples of 5 us: 5*q+r < 5*p iff q < p.
    assign servo_out = enable && (frame_count < selected_pulse);

    always @(posedge clk) begin
        if (rst) begin
            frame_count   <= 0;
            frame_sub_us  <= 3'd0;
            active_angle  <= 3'd0;
            was_enabled   <= 1'b0;
            angle_applied <= 1'b0;
            sweep_pulse_units <= PULSE_MIN;
            continuous_angle <= 8'd0;
            continuous_angle_bcd <= 12'h000;
            angle_phase <= 5'd10;
            direction_up <= 1'b1;
            frame_start <= 1'b0;
        end else begin
            angle_applied <= 1'b0;
            was_enabled   <= enable;
            frame_start <= 1'b0;
            if (SUPPORT_CONTINUOUS) begin
                if (!enable || !continuous_active || !sweep_run) begin
                    sweep_pulse_units <= PULSE_MIN;
                    continuous_angle <= 8'd0;
                    continuous_angle_bcd <= 12'h000;
                    angle_phase <= 5'd10;
                    direction_up <= 1'b1;
                end else if (tick_us && was_enabled && frame_last) begin
                    // 5 us corresponds exactly to 9/20 degree. The initial
                    // phase of 10 implements nearest-integer rounding.
                    if (sweep_endpoint) begin
                        sweep_pulse_units <= direction_up ? PULSE_MAX : PULSE_MIN;
                        continuous_angle <= direction_up ? 8'd180 : 8'd0;
                        continuous_angle_bcd <= direction_up ? 12'h180 : 12'h000;
                        angle_phase <= 5'd10;
                        direction_up <= !direction_up;
                    end else begin
                        // Constants are two's-complement deltas, so each
                        // register uses one adder instead of separate +/- paths.
                        sweep_pulse_units <= sweep_pulse_units + (direction_up ? PULSE_STEP : -PULSE_STEP);
                        angle_phase <= angle_phase + phase_delta;
                        if (degree_step) begin
                            continuous_angle <= continuous_angle + (direction_up ? 8'd1 : 8'hff);
                            continuous_angle_bcd <= bcd_step(continuous_angle_bcd, direction_up);
                        end
                    end
                end
                if (enable && ((!was_enabled) || (tick_us && frame_last))) frame_start <= 1'b1;
            end

            if (!enable) begin
                frame_count  <= 0;
                frame_sub_us <= 3'd0;
                active_angle <= angle_idx;
            end else if (!was_enabled) begin
                frame_count   <= 0;
                frame_sub_us  <= 3'd0;
                active_angle  <= angle_idx;
                angle_applied <= 1'b1;
            end else if (tick_us) begin
                if (frame_last) begin
                    frame_count   <= 0;
                    frame_sub_us  <= 3'd0;
                    active_angle  <= angle_idx;
                    angle_applied <= (active_angle != angle_idx);
                end else begin
                    if (frame_unit_last) begin
                        frame_count <= frame_count + 1'b1;
                        frame_sub_us <= 3'd0;
                    end else begin
                        frame_sub_us <= frame_sub_us + 1'b1;
                    end
                end
            end
        end
    end
endmodule
