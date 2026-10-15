`timescale 1ns/1ps

module timebase #(
    parameter integer CLK_HZ = 50_000_000
) (
    input  wire clk,
    input  wire rst,
    output reg  tick_us,
    output reg  tick_ms,
    output reg  blink_2hz
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

    localparam integer CYCLES_PER_US = CLK_HZ / 1_000_000;

    reg [count_width(CYCLES_PER_US)-1:0] us_div;
    reg [9:0] us_in_ms;
    reg [7:0] ms_in_half_blink;

    initial begin
        if ((CLK_HZ < 1_000_000) || ((CLK_HZ % 1_000_000) != 0)) begin
            $display("ERROR: CLK_HZ must be an integer multiple of 1 MHz");
            $finish;
        end
    end

    always @(posedge clk) begin
        if (rst) begin
            us_div           <= 0;
            us_in_ms         <= 0;
            ms_in_half_blink <= 0;
            tick_us          <= 1'b0;
            tick_ms          <= 1'b0;
            blink_2hz        <= 1'b1;
        end else begin
            tick_us <= 1'b0;
            tick_ms <= 1'b0;

            if (us_div == CYCLES_PER_US - 1) begin
                us_div  <= 0;
                tick_us <= 1'b1;

                if (us_in_ms == 999) begin
                    us_in_ms <= 0;
                    tick_ms  <= 1'b1;
                    if (ms_in_half_blink == 249) begin
                        ms_in_half_blink <= 0;
                        blink_2hz        <= ~blink_2hz;
                    end else begin
                        ms_in_half_blink <= ms_in_half_blink + 1'b1;
                    end
                end else begin
                    us_in_ms <= us_in_ms + 1'b1;
                end
            end else begin
                us_div <= us_div + 1'b1;
            end
        end
    end
endmodule
