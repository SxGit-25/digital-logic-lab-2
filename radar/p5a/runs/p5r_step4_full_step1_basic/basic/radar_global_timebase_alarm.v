`timescale 1ns/1ps

module radar_global_timebase_alarm #(
    parameter integer CLK_HZ = 50_000_000,
    parameter integer SWITCH_SAMPLE_MS=20
) (
    input  wire clk,
    input  wire rst,
    output reg  tick_us,
    output reg  tick_ms,
    output reg tick_250us,
    output wire tick_20ms,tick_switch,
    output reg [14:0] frame_us,
    input wire [2:0] display_index,
    output reg [1:0] color_phase,
    output reg carrier_2khz,
    output wire window_50ms,
    output reg [2:0] rhythm_phase,
    output wire blink_2hz
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
    reg [6:0] ms_in_125;
    assign window_50ms=ms_in_125<50;
    assign blink_2hz=~rhythm_phase[1];

    generate
    if(SWITCH_SAMPLE_MS==20) begin assign tick_switch=tick_20ms;end
    else if(SWITCH_SAMPLE_MS==1) begin assign tick_switch=tick_ms;end
    else begin
        reg [count_width(SWITCH_SAMPLE_MS)-1:0] switch_ms;
        assign tick_switch=tick_ms && switch_ms==SWITCH_SAMPLE_MS-1;
        always @(posedge clk) begin
            if(rst) switch_ms<=0;
            else if(tick_ms) begin
                if(switch_ms==SWITCH_SAMPLE_MS-1) switch_ms<=0;
                else switch_ms<=switch_ms+1'b1;
            end
        end
    end
    endgenerate
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
            ms_in_125 <= 0;
            tick_us          <= 1'b0;
            tick_ms          <= 1'b0;
            tick_250us<=0;
            rhythm_phase<=0;
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
                    if (ms_in_125 == 124) begin
                        ms_in_125 <= 0;
                        rhythm_phase<=rhythm_phase+1'b1;
                    end else begin
                        ms_in_125 <= ms_in_125 + 1'b1;
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
