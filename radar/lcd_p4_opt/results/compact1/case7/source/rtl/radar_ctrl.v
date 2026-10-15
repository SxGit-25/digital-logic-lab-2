`timescale 1ns/1ps

module radar_ctrl #(
    parameter integer SELF_TEST_MS = 2000,
    parameter integer STANDBY_MS   = 2000,
    parameter integer SLOT_MS      = 2000,
    parameter integer SETTLE_MS    = 300,
    parameter integer SUPPORT_CONTINUOUS = 0,
    parameter integer CONTINUOUS_SAMPLE_MS = 60
) (
    input  wire        clk,
    input  wire        rst,
    input  wire        tick_ms,
    input  wire        system_on,
    input  wire        angle_applied,
    input  wire        measure_busy,
    input  wire        measure_done,
    input  wire [11:0] distance_mm,
    input  wire        distance_valid,
    output reg  [1:0]  system_state,
    output reg         servo_enable,
    output reg  [2:0]  angle_idx,
    output reg         measure_start,
    output reg         measure_cancel,
    output reg  [2:0]  sample_idx,
    output reg  [11:0] current_distance,
    output reg         current_valid,
    output reg  [2:0]  current_level,
    output reg  [2:0]  hist_level0,
    output reg  [2:0]  hist_level1,
    output reg  [2:0]  hist_level2,
    output reg  [2:0]  hist_level3,
    output reg  [2:0]  hist_level4,
    output reg  [4:0]  hist_valid,
    output reg  [4:0]  hist_seen,
    input wire continuous_mode,
    input wire [7:0] continuous_angle,
    input wire continuous_direction_up,
    output reg [7:0] sample_angle,
    output reg sample_direction_up
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

    localparam [1:0] SYS_OFF     = 2'd0;
    localparam [1:0] SYS_SELF    = 2'd1;
    localparam [1:0] SYS_STANDBY = 2'd2;
    localparam [1:0] SYS_RUN     = 2'd3;

    localparam [2:0] PH_WAIT_APPLIED = 3'd0;
    localparam [2:0] PH_SETTLE        = 3'd1;
    localparam [2:0] PH_WAIT_MEASURE  = 3'd2;
    localparam [2:0] PH_HOLD          = 3'd3;

    localparam integer STATE_MS = (SELF_TEST_MS > STANDBY_MS) ? SELF_TEST_MS : STANDBY_MS;
    reg [count_width(STATE_MS)-1:0] state_ms;
    localparam integer SLOT_COUNT_MS = SUPPORT_CONTINUOUS && CONTINUOUS_SAMPLE_MS > SLOT_MS ? CONTINUOUS_SAMPLE_MS : SLOT_MS;
    reg [count_width(SLOT_COUNT_MS)-1:0] slot_ms;
    reg [count_width(SETTLE_MS)-1:0] settle_ms;
    reg [2:0] phase;
    reg direction_up;

    wire continuous_active = SUPPORT_CONTINUOUS && continuous_mode;
    function [2:0] nearest_line;
        input [7:0] degrees;
        begin
            if (degrees < 8'd23) nearest_line = 0;
            else if (degrees < 8'd68) nearest_line = 1;
            else if (degrees < 8'd113) nearest_line = 2;
            else if (degrees < 8'd158) nearest_line = 3;
            else nearest_line = 4;
        end
    endfunction

    function [2:0] distance_level;
        input [11:0] mm;
        begin
            if (mm >= 12'd800)
                distance_level = 3'd1;
            else if (mm >= 12'd600)
                distance_level = 3'd2;
            else if (mm >= 12'd400)
                distance_level = 3'd3;
            else if (mm >= 12'd200)
                distance_level = 3'd4;
            else
                distance_level = 3'd5;
        end
    endfunction

    always @(posedge clk) begin
        if (rst) begin
            system_state    <= SYS_OFF;
            servo_enable    <= 1'b0;
            angle_idx       <= 3'd0;
            measure_start   <= 1'b0;
            measure_cancel  <= 1'b1;
            sample_idx      <= 3'd0;
            current_distance<= 12'd0;
            current_valid   <= 1'b0;
            current_level   <= 3'd0;
            hist_level0     <= 3'd0;
            hist_level1     <= 3'd0;
            hist_level2     <= 3'd0;
            hist_level3     <= 3'd0;
            hist_level4     <= 3'd0;
            hist_valid      <= 5'b0;
            hist_seen       <= 5'b0;
            sample_angle <= 0;
            sample_direction_up <= 1'b1;
            state_ms        <= 0;
            slot_ms         <= 0;
            settle_ms       <= 0;
            phase           <= PH_SETTLE;
            direction_up    <= 1'b1;
        end else begin
            measure_start <= 1'b0;

            // measure_start is registered: ultrasonic accepts it on this
            // edge. Bind the sample to the applied command on that edge,
            // including a servo frame change on the preceding edge.
            if (continuous_active && measure_start) begin
                sample_idx <= nearest_line(continuous_angle);
                sample_angle <= continuous_angle;
                sample_direction_up <= continuous_direction_up;
            end

            if (!system_on) begin
                system_state     <= SYS_OFF;
                servo_enable     <= 1'b0;
                angle_idx        <= 3'd0;
                measure_cancel   <= 1'b1;
                current_distance <= 12'd0;
                current_valid    <= 1'b0;
                current_level    <= 3'd0;
                hist_level0      <= 3'd0;
                hist_level1      <= 3'd0;
                hist_level2      <= 3'd0;
                hist_level3      <= 3'd0;
                hist_level4      <= 3'd0;
                hist_valid       <= 5'b0;
                hist_seen        <= 5'b0;
                state_ms         <= 0;
                slot_ms          <= 0;
                settle_ms        <= 0;
                phase            <= PH_SETTLE;
                direction_up     <= 1'b1;
            end else begin
                measure_cancel <= 1'b0;

                case (system_state)
                    SYS_OFF: begin
                        system_state <= SYS_SELF;
                        state_ms     <= 0;
                    end

                    SYS_SELF: begin
                        servo_enable <= 1'b0;
                        if (tick_ms) begin
                            if (state_ms == SELF_TEST_MS - 1) begin
                                system_state <= SYS_STANDBY;
                                state_ms     <= 0;
                                angle_idx    <= 3'd0;
                                servo_enable <= 1'b1;
                            end else begin
                                state_ms <= state_ms + 1'b1;
                            end
                        end
                    end

                    SYS_STANDBY: begin
                        servo_enable <= 1'b1;
                        angle_idx    <= 3'd0;
                        if (tick_ms) begin
                            if (state_ms == STANDBY_MS - 1) begin
                                system_state     <= SYS_RUN;
                                state_ms         <= 0;
                                slot_ms          <= 0;
                                settle_ms        <= 0;
                                phase            <= PH_SETTLE;
                                direction_up     <= 1'b1;
                                current_valid    <= 1'b0;
                                current_level    <= 3'd0;
                            end else begin
                                state_ms <= state_ms + 1'b1;
                            end
                        end
                    end

                    SYS_RUN: begin
                        servo_enable <= 1'b1;

                        if ((phase == PH_WAIT_APPLIED) && angle_applied) begin
                            phase     <= PH_SETTLE;
                            settle_ms <= 0;
                        end

                        if (measure_done && (phase == PH_WAIT_MEASURE)) begin
                            current_distance <= distance_mm;
                            current_valid    <= distance_valid;
                            current_level    <= distance_valid ? distance_level(distance_mm) : 3'd0;
                            phase            <= PH_HOLD;
                            case (sample_idx)
                                3'd0: hist_level0 <= distance_level(distance_mm);
                                3'd1: hist_level1 <= distance_level(distance_mm);
                                3'd2: hist_level2 <= distance_level(distance_mm);
                                3'd3: hist_level3 <= distance_level(distance_mm);
                                3'd4: hist_level4 <= distance_level(distance_mm);
                            endcase
                            case (sample_idx)
                                3'd0: begin hist_seen[0] <= 1'b1; hist_valid[0] <= distance_valid; end
                                3'd1: begin hist_seen[1] <= 1'b1; hist_valid[1] <= distance_valid; end
                                3'd2: begin hist_seen[2] <= 1'b1; hist_valid[2] <= distance_valid; end
                                3'd3: begin hist_seen[3] <= 1'b1; hist_valid[3] <= distance_valid; end
                                3'd4: begin hist_seen[4] <= 1'b1; hist_valid[4] <= distance_valid; end
                            endcase
                        end

                        if (tick_ms) begin
                            if (continuous_active) begin
                                if (slot_ms == CONTINUOUS_SAMPLE_MS - 1) begin
                                    slot_ms <= 0;
                                    if (!measure_busy && phase != PH_WAIT_MEASURE) begin
                                        measure_start <= 1'b1;
                                        phase <= PH_WAIT_MEASURE;
                                    end
                                end else slot_ms <= slot_ms + 1'b1;
                            end else if (slot_ms == SLOT_MS - 1) begin
                                // A slot always ends on time.  Anything not
                                // committed by then becomes an invalid sample.
                                if ((phase != PH_HOLD) && !measure_done) begin
                                    measure_cancel <= 1'b1;
                                    case (angle_idx)
                                        3'd0: begin hist_seen[0] <= 1'b1; hist_valid[0] <= 1'b0; end
                                        3'd1: begin hist_seen[1] <= 1'b1; hist_valid[1] <= 1'b0; end
                                        3'd2: begin hist_seen[2] <= 1'b1; hist_valid[2] <= 1'b0; end
                                        3'd3: begin hist_seen[3] <= 1'b1; hist_valid[3] <= 1'b0; end
                                        3'd4: begin hist_seen[4] <= 1'b1; hist_valid[4] <= 1'b0; end
                                    endcase
                                end

                                slot_ms       <= 0;
                                settle_ms     <= 0;
                                phase         <= PH_WAIT_APPLIED;
                                current_valid <= 1'b0;
                                current_level <= 3'd0;

                                if (direction_up) begin
                                    if (angle_idx == 3'd4) begin
                                        direction_up <= 1'b0;
                                        angle_idx    <= 3'd3;
                                    end else begin
                                        angle_idx <= angle_idx + 1'b1;
                                    end
                                end else begin
                                    if (angle_idx == 3'd0) begin
                                        direction_up <= 1'b1;
                                        angle_idx    <= 3'd1;
                                    end else begin
                                        angle_idx <= angle_idx - 1'b1;
                                    end
                                end
                            end else begin
                                slot_ms <= slot_ms + 1'b1;
                                if (phase == PH_SETTLE) begin
                                    if (settle_ms == SETTLE_MS - 1) begin
                                        if (!measure_busy) begin
                                            measure_start <= 1'b1;
                                            sample_idx    <= angle_idx;
                                            phase         <= PH_WAIT_MEASURE;
                                        end
                                    end else begin
                                        settle_ms <= settle_ms + 1'b1;
                                    end
                                end
                            end
                        end
                    end

                    default: system_state <= SYS_OFF;
                endcase
            end
        end
    end
endmodule
