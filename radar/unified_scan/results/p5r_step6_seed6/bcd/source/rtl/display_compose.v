`timescale 1ns/1ps

module display_compose #(parameter integer SUPPORT_CONTINUOUS = 0) (
    input  wire [1:0]  system_state,
    input  wire        blink_2hz,
    input  wire [2:0]  angle_idx,
    input  wire [15:0] distance_bcd,
    input  wire        current_valid,
    input  wire [2:0]  hist_level0,
    input  wire [2:0]  hist_level1,
    input  wire [2:0]  hist_level2,
    input  wire [2:0]  hist_level3,
    input  wire [2:0]  hist_level4,
    input  wire [4:0]  hist_valid,
    input  wire [4:0]  hist_seen,
    input  wire [2:0]  row_idx,
    output reg  [31:0] digit_codes,
    output reg  [23:0] row_colors,
    input wire continuous_mode,
    input wire [11:0] continuous_angle_bcd
);
    localparam [1:0] SYS_OFF     = 2'd0;
    localparam [1:0] SYS_SELF    = 2'd1;
    localparam [1:0] SYS_STANDBY = 2'd2;
    localparam [1:0] SYS_RUN     = 2'd3;

    localparam [3:0] DIGIT_DASH  = 4'hA;
    localparam [3:0] DIGIT_BLANK = 4'hF;

    localparam [2:0] C_OFF        = 3'd0;
    localparam [2:0] C_GREEN      = 3'd1;
    localparam [2:0] C_YEL_GREEN  = 3'd2;
    localparam [2:0] C_YELLOW     = 3'd3;
    localparam [2:0] C_ORANGE     = 3'd4;
    localparam [2:0] C_RED        = 3'd5;

    reg [3:0] a2, a1, a0;
    reg [3:0] d3, d2, d1, d0;
    reg [2:0] c0, c1, c2, c3, c4;

    function [2:0] visible_color;
        input       seen;
        input       valid;
        input [2:0] level;
        begin
            if (!seen)
                visible_color = C_GREEN;
            else if (!valid)
                visible_color = C_OFF;
            else begin
                case (level)
                    3'd1: visible_color = C_GREEN;
                    3'd2: visible_color = C_YEL_GREEN;
                    3'd3: visible_color = C_YELLOW;
                    3'd4: visible_color = C_ORANGE;
                    3'd5: visible_color = C_RED;
                    default: visible_color = C_OFF;
                endcase
            end
        end
    endfunction

    function [23:0] pixels;
        input [2:0] p0, p1, p2, p3, p4, p5, p6, p7;
        begin
            pixels = {p7, p6, p5, p4, p3, p2, p1, p0};
        end
    endfunction

    always @(*) begin
        case (angle_idx)
            3'd0: begin a2 = 4'd0; a1 = 4'd0; a0 = 4'd0; end
            3'd1: begin a2 = 4'd0; a1 = 4'd4; a0 = 4'd5; end
            3'd2: begin a2 = 4'd0; a1 = 4'd9; a0 = 4'd0; end
            3'd3: begin a2 = 4'd1; a1 = 4'd3; a0 = 4'd5; end
            3'd4: begin a2 = 4'd1; a1 = 4'd8; a0 = 4'd0; end
            default: begin a2 = DIGIT_DASH; a1 = DIGIT_DASH; a0 = DIGIT_DASH; end
        endcase

        if (SUPPORT_CONTINUOUS && continuous_mode) begin
            a2 = continuous_angle_bcd[11:8];
            a1 = continuous_angle_bcd[7:4];
            a0 = continuous_angle_bcd[3:0];
        end

        d3 = distance_bcd[15:12];
        d2 = distance_bcd[11:8];
        d1 = distance_bcd[7:4];
        d0 = distance_bcd[3:0];

        case (system_state)
            SYS_SELF:
                digit_codes = blink_2hz ? 32'h88888888 : 32'hFFFFFFFF;
            SYS_STANDBY:
                digit_codes = {4'd0, 4'd0, 4'd0, DIGIT_BLANK,
                               DIGIT_DASH, DIGIT_DASH, DIGIT_DASH, DIGIT_DASH};
            SYS_RUN:
                digit_codes = current_valid ?
                    {a2, a1, a0, DIGIT_BLANK, d3, d2, d1, d0} :
                    {a2, a1, a0, DIGIT_BLANK,
                     DIGIT_DASH, DIGIT_DASH, DIGIT_DASH, DIGIT_DASH};
            default:
                digit_codes = 32'hFFFFFFFF;
        endcase

        c0 = visible_color(hist_seen[0], hist_valid[0], hist_level0);
        c1 = visible_color(hist_seen[1], hist_valid[1], hist_level1);
        c2 = visible_color(hist_seen[2], hist_valid[2], hist_level2);
        c3 = visible_color(hist_seen[3], hist_valid[3], hist_level3);
        c4 = visible_color(hist_seen[4], hist_valid[4], hist_level4);

        if ((system_state == SYS_OFF) ||
            ((system_state == SYS_SELF) && !blink_2hz)) begin
            row_colors = 24'd0;
        end else if (system_state == SYS_SELF) begin
            row_colors = {8{C_YELLOW}};
        end else if ((system_state == SYS_STANDBY) ||
                     (system_state == SYS_RUN)) begin
            if (system_state == SYS_STANDBY) begin
                c0 = C_GREEN;
                c1 = C_GREEN;
                c2 = C_GREEN;
                c3 = C_GREEN;
                c4 = C_GREEN;
            end
            case (row_idx)
                3'd0: row_colors = pixels(C_OFF, C_OFF, C_OFF, c2,    C_OFF, C_OFF, C_OFF, C_OFF);
                3'd1: row_colors = pixels(c3,    C_OFF, C_OFF, c2,    C_OFF, C_OFF, c1,    C_OFF);
                3'd2: row_colors = pixels(C_OFF, c3,    C_OFF, c2,    C_OFF, c1,    C_OFF, C_OFF);
                3'd3: row_colors = pixels(C_OFF, C_OFF, c3,    c2,    c1,    C_OFF, C_OFF, C_OFF);
                3'd4: row_colors = pixels(c4,    c4,    c4,    C_GREEN,c0,   c0,    c0,    C_OFF);
                default: row_colors = 24'd0;
            endcase
        end else begin
            row_colors = 24'd0;
        end
    end
endmodule
