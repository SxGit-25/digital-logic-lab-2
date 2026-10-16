`timescale 1ns/1ps
// Pure column generator. LCD accesses remain in the unified drawing FSM.
// kind: 0 angle, 1 distance, 2 inverse mode word, 3 level bar.
// char_index runs left-to-right, font_col is 0..5.
module p5_ui_columns (
    input wire [1:0] kind,
    input wire [1:0] char_index,
    input wire [2:0] font_col,
    input wire [11:0] angle_bcd,
    input wire [15:0] distance_bcd,
    input wire mode_continuous,
    input wire [2:0] level,
    input wire [4:0] level_offset,
    output reg [7:0] column_byte
);
    reg [3:0] digit;
    reg [6:0] segments;
    reg [7:0] glyph;
    function [6:0] decode;
        input [3:0] code;
        begin
            // Same active-high abcdefg convention as radar_display_shared.
            case(code)
                0:decode=7'b1111110; 1:decode=7'b0110000;
                2:decode=7'b1101101; 3:decode=7'b1111001;
                4:decode=7'b0110011; 5:decode=7'b1011011;
                6:decode=7'b1011111; 7:decode=7'b1110000;
                8:decode=7'b1111111; 9:decode=7'b1111011;
                10:decode=7'b0000001; default:decode=0;
            endcase
        end
    endfunction
    always @* begin
        digit=4'hf;
        if(kind==0) begin
            case(char_index)
                0:digit=angle_bcd[11:8];
                1:digit=angle_bcd[7:4];
                2:digit=angle_bcd[3:0];
                default:digit=4'hf;
            endcase
        end else begin
            case(char_index)
                0:digit=distance_bcd[15:12];
                1:digit=distance_bcd[11:8];
                2:digit=distance_bcd[7:4];
                3:digit=distance_bcd[3:0];
            endcase
        end
        segments=decode(digit);
        if(kind==2) begin
            case(char_index)
                0:segments=7'b1011011; // 5
                1:segments=mode_continuous ? 7'b1001110 : 7'b0001111; // C / t
                2:segments=mode_continuous ? 7'b1110111 : 7'b1001111; // A / E
                3:segments=mode_continuous ? 7'b0010101 : 7'b1100111; // n / P
            endcase
        end
        case(font_col)
            0:glyph=({8{segments[1]}} & 8'h06) | ({8{segments[2]}} & 8'h30);
            1,2,3:glyph=({8{segments[6]}} & 8'h01) |
                        ({8{segments[0]}} & 8'h08) | ({8{segments[3]}} & 8'h40);
            4:glyph=({8{segments[5]}} & 8'h06) | ({8{segments[4]}} & 8'h30);
            default:glyph=0;
        endcase
        column_byte=kind==2 ? ~glyph : glyph;
        if(kind==3) begin
            column_byte=0;
            if(level_offset<20 && level_offset[1:0]!=3)
                column_byte=(level_offset[4:2]<level) ? 8'h7e : 8'h42;
        end
    end
endmodule
