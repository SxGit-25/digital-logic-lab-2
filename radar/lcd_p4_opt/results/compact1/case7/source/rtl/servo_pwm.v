`timescale 1ns/1ps

module servo_pwm #(parameter integer SUPPORT_CONTINUOUS = 0) (
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
    reg [14:0] frame_us;
    reg [2:0]  active_angle;
    reg        was_enabled;
    reg [11:0] pulse_us;
    reg [11:0] sweep_pulse_us;
    reg [4:0] angle_phase;
    wire continuous_active = SUPPORT_CONTINUOUS && continuous_mode;
    wire [11:0] selected_pulse_us = continuous_active ? sweep_pulse_us : pulse_us;
    wire degree_step = direction_up ? (angle_phase >= 5'd11) : (angle_phase < 5'd9);
    wire [4:0] phase_delta = direction_up ? (degree_step ? 5'd21 : 5'd9) :
                                                         (degree_step ? 5'd11 : 5'd23);
    wire sweep_endpoint = direction_up ? (sweep_pulse_us == 12'd2495) :
                                         (sweep_pulse_us == 12'd505);

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
            3'd0: pulse_us = 12'd500;
            3'd1: pulse_us = 12'd1000;
            3'd2: pulse_us = 12'd1500;
            3'd3: pulse_us = 12'd2000;
            3'd4: pulse_us = 12'd2500;
            default: pulse_us = 12'd500;
        endcase
    end

    assign servo_out = enable && (frame_us < selected_pulse_us);

    always @(posedge clk) begin
        if (rst) begin
            frame_us      <= 15'd0;
            active_angle  <= 3'd0;
            was_enabled   <= 1'b0;
            angle_applied <= 1'b0;
            sweep_pulse_us <= 12'd500;
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
                    sweep_pulse_us <= 12'd500;
                    continuous_angle <= 8'd0;
                    continuous_angle_bcd <= 12'h000;
                    angle_phase <= 5'd10;
                    direction_up <= 1'b1;
                end else if (tick_us && was_enabled && frame_us == 15'd19999) begin
                    // 5 us corresponds exactly to 9/20 degree. The initial
                    // phase of 10 implements nearest-integer rounding.
                    if (sweep_endpoint) begin
                        sweep_pulse_us <= direction_up ? 12'd2500 : 12'd500;
                        continuous_angle <= direction_up ? 8'd180 : 8'd0;
                        continuous_angle_bcd <= direction_up ? 12'h180 : 12'h000;
                        angle_phase <= 5'd10;
                        direction_up <= !direction_up;
                    end else begin
                        // Constants are two's-complement deltas, so each
                        // register uses one adder instead of separate +/- paths.
                        sweep_pulse_us <= sweep_pulse_us + (direction_up ? 12'd5 : 12'hffb);
                        angle_phase <= angle_phase + phase_delta;
                        if (degree_step) begin
                            continuous_angle <= continuous_angle + (direction_up ? 8'd1 : 8'hff);
                            continuous_angle_bcd <= bcd_step(continuous_angle_bcd, direction_up);
                        end
                    end
                end
                if (enable && ((!was_enabled) || (tick_us && frame_us == 15'd19999))) frame_start <= 1'b1;
            end

            if (!enable) begin
                frame_us     <= 15'd0;
                active_angle <= angle_idx;
            end else if (!was_enabled) begin
                frame_us      <= 15'd0;
                active_angle  <= angle_idx;
                angle_applied <= 1'b1;
            end else if (tick_us) begin
                if (frame_us == 15'd19999) begin
                    frame_us      <= 15'd0;
                    active_angle  <= angle_idx;
                    angle_applied <= (active_angle != angle_idx);
                end else begin
                    frame_us <= frame_us + 1'b1;
                end
            end
        end
    end
endmodule
