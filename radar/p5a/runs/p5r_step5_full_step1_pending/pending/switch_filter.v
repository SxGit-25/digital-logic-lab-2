`timescale 1ns/1ps

module switch_filter #(
    parameter integer FILTER_MS = 20
) (
    input  wire clk,
    input  wire rst,
    input  wire tick_ms,
    input  wire sw_raw,
    output reg  system_on
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

    reg sw_meta;
    reg sw_sync;
    reg [count_width(FILTER_MS)-1:0] stable_ms;

    always @(posedge clk) begin
        if (rst) begin
            sw_meta   <= 1'b0;
            sw_sync   <= 1'b0;
            system_on <= 1'b0;
            stable_ms <= 0;
        end else begin
            sw_meta <= sw_raw;
            sw_sync <= sw_meta;

            if (tick_ms) begin
                if (sw_sync == system_on) begin
                    stable_ms <= 0;
                end else if (stable_ms == FILTER_MS - 1) begin
                    system_on <= sw_sync;
                    stable_ms <= 0;
                end else begin
                    stable_ms <= stable_ms + 1'b1;
                end
            end
        end
    end
endmodule
