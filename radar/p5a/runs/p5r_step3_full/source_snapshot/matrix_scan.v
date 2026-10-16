`timescale 1ns/1ps

module matrix_scan #(
    parameter integer PHASE_US = 250
) (
    input  wire        clk,
    input  wire        rst,
    input  wire        tick_us,
    input  wire        enable,
    input  wire [23:0] row_colors,
    output reg  [2:0]  row_idx,
    output reg  [7:0]  row_n,
    output reg  [7:0]  col_r,
    output reg  [7:0]  col_g
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

    reg [1:0] pwm_phase;
    reg [count_width(PHASE_US)-1:0] phase_us;
    reg [1:0] blank_stage;
    integer i;

    function red_on;
        input [2:0] color;
        input [1:0] phase;
        begin
            case (color)
                3'd2: red_on = (phase == 2'd0);
                3'd3: red_on = (phase < 2'd2);
                3'd4: red_on = (phase < 2'd3);
                3'd5: red_on = 1'b1;
                default: red_on = 1'b0;
            endcase
        end
    endfunction

    function green_on;
        input [2:0] color;
        input [1:0] phase;
        begin
            case (color)
                3'd1: green_on = 1'b1;
                3'd2: green_on = (phase != 2'd0);
                3'd3: green_on = (phase >= 2'd2);
                3'd4: green_on = (phase == 2'd3);
                default: green_on = 1'b0;
            endcase
        end
    endfunction

    always @(posedge clk) begin
        if (rst || !enable) begin
            row_idx     <= 3'd0;
            pwm_phase   <= 2'd0;
            phase_us    <= 0;
            blank_stage <= 2'd1;
            row_n       <= 8'hFF;
            col_r       <= 8'h00;
            col_g       <= 8'h00;
        end else if (blank_stage == 2'd1) begin
            for (i = 0; i < 8; i = i + 1) begin
                col_r[i] <= red_on(row_colors[i*3 +: 3], pwm_phase);
                col_g[i] <= green_on(row_colors[i*3 +: 3], pwm_phase);
            end
            blank_stage <= 2'd2;
        end else if (blank_stage == 2'd2) begin
            row_n       <= ~(8'b00000001 << row_idx);
            blank_stage <= 2'd0;
        end else if (tick_us) begin
            if (phase_us == PHASE_US - 1) begin
                phase_us <= 0;
                row_n    <= 8'hFF;
                if (pwm_phase == 2'd3) begin
                    pwm_phase <= 2'd0;
                    row_idx   <= row_idx + 1'b1;
                end else begin
                    pwm_phase <= pwm_phase + 1'b1;
                end
                blank_stage <= 2'd1;
            end else begin
                phase_us <= phase_us + 1'b1;
            end
        end
    end
endmodule
