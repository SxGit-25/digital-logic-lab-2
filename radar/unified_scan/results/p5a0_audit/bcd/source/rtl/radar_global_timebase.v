`timescale 1ns/1ps

module radar_global_timebase #(
    parameter integer CLK_HZ = 50_000_000
) (
    input  wire clk,
    input  wire rst,
    output reg  tick_us,
    output reg  tick_ms,
    output reg tick_250us,
    output wire tick_20ms,
    output reg [14:0] frame_us,
    input wire [2:0] display_index,
    output reg [1:0] color_phase,
    output reg carrier_2khz,
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

    assign tick_20ms=tick_us && frame_us==19999;
    always @(posedge clk) begin
        if(rst) begin frame_us<=0;color_phase<=0;carrier_2khz<=0;end
        else begin
            if(tick_us) begin
                if(frame_us==19999) frame_us<=0;
                else frame_us<=frame_us+1'b1;
            end
            if(tick_250us) begin
                carrier_2khz<=~carrier_2khz;
                if(display_index==7) color_phase<=color_phase+1'b1;
            end
        end
    end
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
            tick_250us<=0;
            blink_2hz        <= 1'b1;
        end else begin
            tick_us <= 1'b0;
            tick_ms <= 1'b0;
            tick_250us<=0;

            if (us_div == CYCLES_PER_US - 1) begin
                us_div  <= 0;
                if(us_in_ms==249 || us_in_ms==499 || us_in_ms==749 || us_in_ms==999) tick_250us<=1;
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
