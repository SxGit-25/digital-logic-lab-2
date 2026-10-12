`timescale 1ns/1ps

module alarm_ctrl #(
    // Board documentation lists pins but not an unambiguous color-to-LD map.
    // These masks keep the mapping in one place for quick correction on board.
    parameter [15:0] BLUE_MASK   = 16'hF000,
    parameter [15:0] GREEN_MASK  = 16'h0F00,
    parameter [15:0] YELLOW_MASK = 16'h00F0,
    parameter [15:0] RED_MASK    = 16'h000F,
    parameter integer CARRIER_HALF_US = 250
) (
    input  wire        clk,
    input  wire        rst,
    input  wire        tick_us,
    input  wire        tick_ms,
    input  wire        blink_2hz,
    input  wire [1:0]  system_state,
    input  wire        current_valid,
    input  wire [2:0]  current_level,
    output reg  [15:0] leds,
    output wire        buzzer
);
    localparam [1:0] SYS_SELF = 2'd1;
    localparam [1:0] SYS_RUN  = 2'd3;

    integer carrier_us;
    integer rhythm_ms;
    integer rhythm_period_ms;
    reg carrier;
    reg sound_gate;

    always @(*) begin
        case (current_level)
            3'd2: rhythm_period_ms = 1000;
            3'd3: rhythm_period_ms = 500;
            3'd4: rhythm_period_ms = 250;
            3'd5: rhythm_period_ms = 125;
            default: rhythm_period_ms = 1000;
        endcase
    end

    always @(*) begin
        leds = 16'h0000;
        if (system_state == SYS_SELF) begin
            leds = blink_2hz ? 16'hFFFF : 16'h0000;
        end else if ((system_state == SYS_RUN) && current_valid) begin
            case (current_level)
                3'd1: leds = BLUE_MASK;
                3'd2: leds = blink_2hz ? GREEN_MASK  : 16'h0000;
                3'd3: leds = blink_2hz ? YELLOW_MASK : 16'h0000;
                3'd4: leds = blink_2hz ? RED_MASK    : 16'h0000;
                3'd5: leds = blink_2hz ? 16'hFFFF    : 16'h0000;
                default: leds = 16'h0000;
            endcase
        end
    end

    assign buzzer = carrier && sound_gate;

    always @(posedge clk) begin
        if (rst) begin
            carrier_us <= 0;
            carrier    <= 1'b0;
        end else if (tick_us) begin
            if (carrier_us == CARRIER_HALF_US - 1) begin
                carrier_us <= 0;
                carrier    <= ~carrier;
            end else begin
                carrier_us <= carrier_us + 1;
            end
        end
    end

    always @(posedge clk) begin
        if (rst || (system_state != SYS_RUN) || !current_valid ||
            (current_level < 3'd2) || (current_level > 3'd5)) begin
            rhythm_ms <= 0;
            sound_gate <= 1'b0;
        end else if (tick_ms) begin
            sound_gate <= (rhythm_ms < 50);
            if (rhythm_ms == rhythm_period_ms - 1)
                rhythm_ms <= 0;
            else
                rhythm_ms <= rhythm_ms + 1;
        end
    end
endmodule
