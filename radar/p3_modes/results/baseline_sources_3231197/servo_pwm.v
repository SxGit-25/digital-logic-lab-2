`timescale 1ns/1ps

module servo_pwm (
    input  wire       clk,
    input  wire       rst,
    input  wire       tick_us,
    input  wire       enable,
    input  wire [2:0] angle_idx,
    output wire       servo_out,
    output reg        angle_applied
);
    reg [14:0] frame_us;
    reg [2:0]  active_angle;
    reg        was_enabled;
    reg [11:0] pulse_us;

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

    assign servo_out = enable && (frame_us < pulse_us);

    always @(posedge clk) begin
        if (rst) begin
            frame_us      <= 15'd0;
            active_angle  <= 3'd0;
            was_enabled   <= 1'b0;
            angle_applied <= 1'b0;
        end else begin
            angle_applied <= 1'b0;
            was_enabled   <= enable;

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
