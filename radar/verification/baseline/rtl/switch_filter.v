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
    reg sw_meta;
    reg sw_sync;
    integer stable_ms;

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
                    stable_ms <= stable_ms + 1;
                end
            end
        end
    end
endmodule
