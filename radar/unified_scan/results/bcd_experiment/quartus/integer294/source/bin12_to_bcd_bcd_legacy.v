`timescale 1ns/1ps

// Resource-saving binary-to-BCD converter.  A new input value is converted
// over 12 clock cycles instead of inferring several large divider blocks.
module bin12_to_bcd_bcd_legacy (
    input  wire        clk,
    input  wire        rst,
    input  wire [11:0] binary,
    output reg  [15:0] bcd
);
    reg [11:0] last_binary;
    reg [27:0] shift_reg;
    reg [27:0] shift_next;
    reg [3:0]  bit_count;
    reg        busy;

    always @(*) begin
        shift_next = shift_reg;
        if (shift_next[15:12] >= 5)
            shift_next[15:12] = shift_next[15:12] + 4'd3;
        if (shift_next[19:16] >= 5)
            shift_next[19:16] = shift_next[19:16] + 4'd3;
        if (shift_next[23:20] >= 5)
            shift_next[23:20] = shift_next[23:20] + 4'd3;
        if (shift_next[27:24] >= 5)
            shift_next[27:24] = shift_next[27:24] + 4'd3;
        shift_next = shift_next << 1;
    end

    always @(posedge clk) begin
        if (rst) begin
            last_binary <= 12'hFFF;
            shift_reg   <= 28'd0;
            bit_count   <= 4'd0;
            busy        <= 1'b0;
            bcd         <= 16'd0;
        end else if (!busy) begin
            if (binary != last_binary) begin
                last_binary <= binary;
                shift_reg   <= {16'd0, binary};
                bit_count   <= 4'd0;
                busy        <= 1'b1;
            end
        end else begin
            shift_reg <= shift_next;
            if (bit_count == 4'd11) begin
                bcd  <= shift_next[27:12];
                busy <= 1'b0;
            end else begin
                bit_count <= bit_count + 1'b1;
            end
        end
    end
endmodule