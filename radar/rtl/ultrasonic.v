`timescale 1ns/1ps

module ultrasonic #(
    parameter integer TRIG_US    = 15,
    parameter integer TIMEOUT_US = 30000
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
    output reg         distance_valid
);
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
    reg [15:0] trigger_us;
    reg [15:0] budget_us;
    reg [15:0] echo_us;

    wire echo_rise = echo_sync && !echo_prev;
    wire echo_fall = !echo_sync && echo_prev;
    // Widen an operand explicitly: 30000 * 17 + 50 needs 19 bits.
    wire [18:0] distance_numerator = (echo_us * 19'd17) + 19'd50;

    assign measure_busy = (state != IDLE) && (state != DONE);

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
            trigger_us       <= 16'd0;
            budget_us        <= 16'd0;
            echo_us          <= 16'd0;
        end else begin
            measure_done <= 1'b0;

            if (cancel) begin
                state          <= IDLE;
                trig           <= 1'b0;
                distance_valid <= 1'b0;
                trigger_us     <= 16'd0;
                budget_us      <= 16'd0;
                echo_us        <= 16'd0;
            end else begin
                case (state)
                    IDLE: begin
                        trig <= 1'b0;
                        if (measure_start) begin
                            state          <= TRIGGER;
                            trig           <= 1'b1;
                            distance_valid <= 1'b0;
                            trigger_us     <= 16'd0;
                            budget_us      <= 16'd0;
                            echo_us        <= 16'd0;
                        end
                    end

                    TRIGGER: begin
                        if (tick_us) begin
                            if (trigger_us == TRIG_US - 1) begin
                                trig       <= 1'b0;
                                trigger_us <= 16'd0;
                                budget_us  <= 16'd0;
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
                            echo_us <= 16'd0;
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
                            end
                        end
                    end

                    CONVERT: begin
                        if ((echo_us >= MIN_ECHO_US) &&
                            (echo_us <= MAX_ECHO_US) && !echo_sync) begin
                            distance_mm    <= distance_numerator / 19'd100;
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
