`timescale 1ns/1ps

module seg_scan #(
    parameter integer DIGIT_US = 250
) (
    input  wire        clk,
    input  wire        rst,
    input  wire        tick_us,
    input  wire        enable,
    input  wire [31:0] digit_codes,
    output reg  [6:0]  seg,
    output reg  [7:0]  cat_n
);
    // Elaboration-time ceil(log2(count)), with one bit for count == 1.
    // Verilog-2001 constant function for Quartus II 9.1 compatibility.
    function integer count_width;
        input integer count;
        integer remaining;
        begin
            remaining = count - 1;
            count_width = 0;
            while (remaining > 0) begin
                count_width = count_width + 1;
                remaining = remaining >> 1;
            end
            if (count_width < 1) count_width = 1;
        end
    endfunction

    reg [2:0] digit_idx;
    reg [count_width(DIGIT_US)-1:0] dwell_us;
    reg blank_pending;

    function [6:0] decode;
        input [3:0] code;
        begin
            case (code)
                4'd0: decode = 7'b1111110;
                4'd1: decode = 7'b0110000;
                4'd2: decode = 7'b1101101;
                4'd3: decode = 7'b1111001;
                4'd4: decode = 7'b0110011;
                4'd5: decode = 7'b1011011;
                4'd6: decode = 7'b1011111;
                4'd7: decode = 7'b1110000;
                4'd8: decode = 7'b1111111;
                4'd9: decode = 7'b1111011;
                4'hA: decode = 7'b0000001;
                default: decode = 7'b0000000;
            endcase
        end
    endfunction

    always @(posedge clk) begin
        if (rst || !enable) begin
            digit_idx     <= 3'd0;
            dwell_us      <= 0;
            blank_pending <= 1'b1;
            seg           <= 7'b0;
            cat_n         <= 8'hFF;
        end else begin
            if (blank_pending) begin
                seg                   <= decode(digit_codes[digit_idx*4 +: 4]);
                cat_n                 <= ~(8'b00000001 << digit_idx);
                blank_pending         <= 1'b0;
            end else if (tick_us) begin
                if (dwell_us == DIGIT_US - 1) begin
                    dwell_us      <= 0;
                    cat_n         <= 8'hFF;
                    digit_idx     <= digit_idx + 1'b1;
                    blank_pending <= 1'b1;
                end else begin
                    dwell_us <= dwell_us + 1'b1;
                end
            end
        end
    end
endmodule
