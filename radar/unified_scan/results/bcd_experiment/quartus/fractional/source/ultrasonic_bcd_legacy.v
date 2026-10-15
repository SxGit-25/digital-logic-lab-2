`timescale 1ns/1ps

module ultrasonic_bcd_legacy #(
    parameter integer TRIG_US    = 15,
    parameter integer TIMEOUT_US = 30000,
    parameter integer ENABLE_RADIUS = 0
) (
    input  wire        clk,
    input  wire        rst,
    input  wire        tick_us,
    input  wire        measure_start,
    input  wire        cancel,
    input  wire        echo_async,
    output reg         trig,
    output wire        measure_busy,
    output reg         measure_done,
    output reg  [11:0] distance_mm,
    output reg         distance_valid,
    output reg  [5:0]  radius,
    output reg         radius_valid
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

    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] TRIGGER   = 3'd1;
    localparam [2:0] WAIT_LOW  = 3'd2;
    localparam [2:0] WAIT_RISE = 3'd3;
    localparam [2:0] COUNT_HIGH= 3'd4;
    localparam [2:0] CONVERT   = 3'd5;
    localparam [2:0] DONE      = 3'd6;

    // 20 mm and 4000 mm boundaries expressed in raw echo microseconds.
    localparam integer MIN_ECHO_US = 118;
    localparam integer MAX_ECHO_US = 23529;

    reg [2:0] state;
    reg echo_meta;
    reg echo_sync;
    reg echo_prev;
    reg [count_width(TRIG_US)-1:0] trigger_us;
    reg [count_width(TIMEOUT_US)-1:0] budget_us;
    reg [count_width(TIMEOUT_US)-1:0] echo_us;
    reg [11:0] distance_work;
    reg [6:0]  distance_rem;

    wire echo_rise = echo_sync && !echo_prev;
    wire echo_fall = !echo_sync && echo_prev;

    assign measure_busy = (state != IDLE) && (state != DONE);

    // Optional LCD radius path. Observe exactly the original millimetre
    // increment events, including its initial rounding remainder of 50.
    // Keep this independent of the original measurement state machine.
    generate
        if (ENABLE_RADIUS != 0) begin : g_radius
            reg [4:0] radius_mod25;
            reg [5:0] radius_work;
            reg radius_over1200;
            always @(posedge clk) begin
                if (rst) begin
                    radius <= 6'd0;
                    radius_valid <= 1'b0;
                    radius_mod25 <= 5'd0;
                    radius_work <= 6'd0;
                    radius_over1200 <= 1'b0;
                end else if (cancel || ((state == IDLE) && measure_start)) begin
                    radius_valid <= 1'b0;
                    radius_mod25 <= 5'd0;
                    radius_work <= 6'd0;
                    radius_over1200 <= 1'b0;
                end else if ((state == WAIT_RISE) && echo_rise) begin
                    radius_mod25 <= 5'd0;
                    radius_work <= 6'd0;
                    radius_over1200 <= 1'b0;
                end else if ((state == COUNT_HIGH) && !echo_fall && tick_us &&
                             (budget_us != TIMEOUT_US - 1) &&
                             (distance_rem >= 7'd83)) begin
                    if (radius_work == 6'd48) begin
                        // The first extra millimetre is 1201, not 1200.
                        radius_over1200 <= 1'b1;
                    end else if (radius_mod25 == 5'd24) begin
                        radius_mod25 <= 5'd0;
                        radius_work <= radius_work + 1'b1;
                    end else begin
                        radius_mod25 <= radius_mod25 + 1'b1;
                    end
                end else if (state == CONVERT) begin
                    if ((echo_us >= MIN_ECHO_US) &&
                        (echo_us <= MAX_ECHO_US) && !echo_sync) begin
                        radius <= radius_work;
                        radius_valid <= !radius_over1200;
                    end else begin
                        radius <= 6'd0;
                        radius_valid <= 1'b0;
                    end
                end
            end
        end else begin : g_no_radius
            always @(posedge clk) begin
                radius <= 6'd0;
                radius_valid <= 1'b0;
            end
        end
    endgenerate

    always @(posedge clk) begin
        if (rst) begin
            echo_meta <= 1'b0;
            echo_sync <= 1'b0;
            echo_prev <= 1'b0;
        end else begin
            echo_meta <= echo_async;
            echo_sync <= echo_meta;
            echo_prev <= echo_sync;
        end
    end

    always @(posedge clk) begin
        if (rst) begin
            state            <= IDLE;
            trig             <= 1'b0;
            measure_done     <= 1'b0;
            distance_mm      <= 12'd0;
            distance_valid   <= 1'b0;
            trigger_us       <= 1'b0;
            budget_us        <= 1'b0;
            echo_us          <= 1'b0;
            distance_work    <= 12'd0;
            distance_rem     <= 7'd50;
        end else begin
            measure_done <= 1'b0;

            if (cancel) begin
                state          <= IDLE;
                trig           <= 1'b0;
                distance_valid <= 1'b0;
                trigger_us     <= 1'b0;
                budget_us      <= 1'b0;
                echo_us        <= 1'b0;
                distance_work  <= 12'd0;
                distance_rem   <= 7'd50;
            end else begin
                case (state)
                    IDLE: begin
                        trig <= 1'b0;
                        if (measure_start) begin
                            state          <= TRIGGER;
                            trig           <= 1'b1;
                            distance_valid <= 1'b0;
                            trigger_us     <= 1'b0;
                            budget_us      <= 1'b0;
                            echo_us        <= 1'b0;
                        end
                    end

                    TRIGGER: begin
                        if (tick_us) begin
                            if (trigger_us == TRIG_US - 1) begin
                                trig       <= 1'b0;
                                trigger_us <= 1'b0;
                                budget_us  <= 1'b0;
                                state      <= echo_sync ? WAIT_LOW : WAIT_RISE;
                            end else begin
                                trigger_us <= trigger_us + 1'b1;
                            end
                        end
                    end

                    WAIT_LOW: begin
                        if (!echo_sync) begin
                            state <= WAIT_RISE;
                        end else if (tick_us) begin
                            if (budget_us == TIMEOUT_US - 1)
                                state <= CONVERT;
                            else
                                budget_us <= budget_us + 1'b1;
                        end
                    end

                    WAIT_RISE: begin
                        if (echo_rise) begin
                            echo_us <= 1'b0;
                            distance_work <= 12'd0;
                            distance_rem  <= 7'd50;
                            state   <= COUNT_HIGH;
                        end else if (tick_us) begin
                            if (budget_us == TIMEOUT_US - 1)
                                state <= CONVERT;
                            else
                                budget_us <= budget_us + 1'b1;
                        end
                    end

                    COUNT_HIGH: begin
                        if (echo_fall) begin
                            state <= CONVERT;
                        end else if (tick_us) begin
                            if (budget_us == TIMEOUT_US - 1) begin
                                state <= CONVERT;
                            end else begin
                                budget_us <= budget_us + 1'b1;
                                echo_us   <= echo_us + 1'b1;
                                // distance_mm = round(echo_us * 17 / 100).
                                // Accumulating the fixed ratio avoids a large
                                // multiplier/divider on the MAX II device.
                                if (distance_rem >= 7'd83) begin
                                    distance_rem  <= distance_rem - 7'd83;
                                    distance_work <= distance_work + 1'b1;
                                end else begin
                                    distance_rem <= distance_rem + 7'd17;
                                end
                            end
                        end
                    end

                    CONVERT: begin
                        if ((echo_us >= MIN_ECHO_US) &&
                            (echo_us <= MAX_ECHO_US) && !echo_sync) begin
                            distance_mm    <= distance_work;
                            distance_valid <= 1'b1;
                        end else begin
                            distance_mm    <= 12'd0;
                            distance_valid <= 1'b0;
                        end
                        state <= DONE;
                    end

                    DONE: begin
                        measure_done <= 1'b1;
                        state        <= IDLE;
                    end

                    default: state <= IDLE;
                endcase
            end
        end
    end
endmodule