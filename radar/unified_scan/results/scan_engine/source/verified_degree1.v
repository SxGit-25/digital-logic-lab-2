`timescale 1ns/1ps

// Unified BCD-only scan command, schedule and five-line measurement history.
// Legacy modules are intentionally independent of this implementation.
module radar_unified_scan #(
    parameter integer SELF_TEST_MS = 2000,
    parameter integer STANDBY_MS = 2000,
    parameter integer SLOT_MS = 2000,
    parameter integer SETTLE_MS = 300,
    parameter integer CONTINUOUS_STEP_MS = 60,
    parameter integer FAST_STEP_US = 16,
    parameter integer HOLD_FAST_PWM = 1
) (
    input wire clk, rst, tick_us, tick_ms,
    input wire enable, continuous_mode,
    input wire measure_busy, measure_done,
    input wire [11:0] distance_mm,
    input wire distance_valid,
    output reg [1:0] system_state,
    output wire servo, servo_enable,
    output reg [11:0] angle_bcd,
    output reg direction_up,
    output reg measure_start, measure_cancel,
    output reg [11:0] sample_angle_bcd,
    output reg sample_direction_up,
    output reg [2:0] sample_idx,
    output reg [11:0] current_distance,
    output reg current_valid,
    output reg [2:0] current_level,
    output reg [2:0] hist_level0, hist_level1, hist_level2,
    output reg [2:0] hist_level3, hist_level4,
    output reg [4:0] hist_valid, hist_seen,
    output reg step_event, sample_event, frame_start,
    output wire fast_busy
);
    function integer count_width;
        input integer n;
        integer r;
        begin
            r = n-1;
            count_width = 0;
            while (r > 0) begin count_width=count_width+1; r=r>>1; end
            if (count_width < 1) count_width=1;
        end
    endfunction
    localparam [1:0] SYS_OFF=0, SYS_SELF=1, SYS_STANDBY=2, SYS_RUN=3;
    localparam integer STARTUP_MAX = SELF_TEST_MS > STANDBY_MS ? SELF_TEST_MS : STANDBY_MS;
    localparam integer SCAN_MAX = SLOT_MS > CONTINUOUS_STEP_MS ? SLOT_MS : CONTINUOUS_STEP_MS;
    localparam integer TIMER_MAX = STARTUP_MAX > SCAN_MAX ? STARTUP_MAX : SCAN_MAX;
    reg [count_width(TIMER_MAX)-1:0] timer_ms;
    reg [count_width(FAST_STEP_US)-1:0] fast_us;
    reg [5:0] fast_steps;
    reg previous_mode, waiting_measure, pending_continuous;
    reg [11:0] command_pulse_us, active_pulse_us;
    reg [3:0] pulse_remainder;
    reg [14:0] frame_us;
    reg was_servo_enabled;
    wire mode_changed = continuous_mode != previous_mode;
    wire running = enable && !mode_changed && system_state == SYS_RUN;
    wire continuous_due = running && continuous_mode && tick_ms &&
                          timer_ms == CONTINUOUS_STEP_MS-1;
    wire basic_due = running && !continuous_mode && tick_ms && timer_ms == SLOT_MS-1;
    wire fast_step_due = running && !continuous_mode && fast_steps != 0 &&
                         tick_us && fast_us == FAST_STEP_US-1;
    wire degree_step = continuous_due || fast_step_due;
    wire frame_latch = servo_enable && was_servo_enabled && tick_us && frame_us == 19999;
    wire continuous_apply = running && continuous_mode && frame_latch &&
                            (pending_continuous || continuous_due);
    wire step_to_endpoint = direction_up ? angle_bcd == 12'h179 : angle_bcd == 12'h001;
    wire [3:0] decimal_delta = direction_up ? 4'd1 : 4'd15;
    wire [3:0] decimal_limit = direction_up ? 4'd9 : 4'd0;
    wire [3:0] decimal_wrap = direction_up ? 4'd0 : 4'd9;
    wire large_pulse_step = direction_up ? pulse_remainder == 8 : pulse_remainder == 0;
    wire [11:0] pulse_delta = direction_up ? (large_pulse_step ? 12'd12 : 12'd11) :
                                            (large_pulse_step ? 12'hff4 : 12'hff5);
    wire [11:0] next_pulse_us = command_pulse_us + pulse_delta;

    function [2:0] nearest_line;
        input [11:0] bcd;
        begin
            if (bcd < 12'h023) nearest_line=0;
            else if (bcd < 12'h068) nearest_line=1;
            else if (bcd < 12'h113) nearest_line=2;
            else if (bcd < 12'h158) nearest_line=3;
            else nearest_line=4;
        end
    endfunction
    function [2:0] level;
        input [11:0] mm;
        begin
            if (mm >= 800) level=1;
            else if (mm >= 600) level=2;
            else if (mm >= 400) level=3;
            else if (mm >= 200) level=4;
            else level=5;
        end
    endfunction
    assign servo_enable = enable && !mode_changed &&
                          (system_state == SYS_STANDBY || system_state == SYS_RUN);
    assign servo = servo_enable && frame_us < active_pulse_us;
    assign fast_busy = fast_steps != 0;

    // A 1 degree command is 100/9 us. The remainder starts at 4 to round
    // to nearest integer microsecond. Downward steps exactly undo upward ones.
    always @(posedge clk) begin
        if (rst || !enable || mode_changed) begin
            angle_bcd <= 0;
            direction_up <= 1;
            command_pulse_us <= 12'd500;
            pulse_remainder <= 4'd4;
            step_event <= 0;
        end else begin
            step_event <= 0;
            if (degree_step) begin
                step_event <= 1;
                if (angle_bcd[3:0] != decimal_limit)
                    angle_bcd[3:0] <= angle_bcd[3:0] + decimal_delta;
                else begin
                    angle_bcd[3:0] <= decimal_wrap;
                    if (angle_bcd[7:4] != decimal_limit)
                        angle_bcd[7:4] <= angle_bcd[7:4] + decimal_delta;
                    else begin
                        angle_bcd[7:4] <= decimal_wrap;
                        angle_bcd[11:8] <= {3'b000,!angle_bcd[8]};
                    end
                end
                if (step_to_endpoint) direction_up <= !direction_up;
                command_pulse_us <= next_pulse_us;
                if (direction_up) begin
                    if (pulse_remainder == 8) begin
                        pulse_remainder <= 0;
                    end else begin
                        pulse_remainder <= pulse_remainder + 1'b1;
                    end
                end else begin
                    if (pulse_remainder == 0) begin
                        pulse_remainder <= 4'd8;
                    end else begin
                        pulse_remainder <= pulse_remainder - 1'b1;
                    end
                end
            end
        end
    end

    // Only this frame boundary changes the pulse applied to the servo pin.
    // HOLD_FAST_PWM is an explicit contract candidate: never emit a partial
    // basic fast-walk target, even when the slot and frame phases differ.
    always @(posedge clk) begin
        if (rst || !servo_enable) begin
            frame_us <= 0;
            active_pulse_us <= 12'd500;
            was_servo_enabled <= 0;
            frame_start <= 0;
        end else begin
            was_servo_enabled <= 1;
            frame_start <= 0;
            if (!was_servo_enabled) begin
                frame_us <= 0;
                active_pulse_us <= command_pulse_us;
                frame_start <= 1;
            end else if (tick_us) begin
                if (frame_us == 19999) begin
                    frame_us <= 0;
                    frame_start <= 1;
                    if (!HOLD_FAST_PWM || continuous_mode || !fast_busy)
                        active_pulse_us <= continuous_due ? next_pulse_us : command_pulse_us;
                end else frame_us <= frame_us + 1'b1;
            end
        end
    end

    always @(posedge clk) begin
        if (rst) previous_mode <= continuous_mode;
        else previous_mode <= continuous_mode;
        if (rst || !enable || mode_changed) begin
            system_state <= SYS_OFF;
            timer_ms <= 0;
            fast_us <= 0;
            fast_steps <= 0;
            waiting_measure <= 0;
            pending_continuous <= 0;
            measure_start <= 0;
            measure_cancel <= 1;
            sample_angle_bcd <= 0;
            sample_direction_up <= 1;
            sample_idx <= 0;
            current_distance <= 0;
            current_valid <= 0;
            current_level <= 0;
            hist_level0 <= 0; hist_level1 <= 0; hist_level2 <= 0;
            hist_level3 <= 0; hist_level4 <= 0;
            hist_valid <= 0; hist_seen <= 0;
            sample_event <= 0;
        end else begin
            measure_start <= 0;
            measure_cancel <= 0;
            sample_event <= 0;
            // Metadata is sampled on the same edge as ultrasonic accepts the
            // registered start, after a same-event BCD degree step has landed.
            if (measure_start) begin
                sample_angle_bcd <= angle_bcd;
                sample_direction_up <= direction_up;
                sample_idx <= nearest_line(angle_bcd);
            end
            if (system_state == SYS_RUN && measure_done && waiting_measure) begin
                waiting_measure <= 0;
                current_distance <= distance_mm;
                current_valid <= distance_valid;
                current_level <= distance_valid ? level(distance_mm) : 0;
                sample_event <= 1;
                case (sample_idx)
                    0: begin hist_level0<=level(distance_mm); hist_valid[0]<=distance_valid; hist_seen[0]<=1; end
                    1: begin hist_level1<=level(distance_mm); hist_valid[1]<=distance_valid; hist_seen[1]<=1; end
                    2: begin hist_level2<=level(distance_mm); hist_valid[2]<=distance_valid; hist_seen[2]<=1; end
                    3: begin hist_level3<=level(distance_mm); hist_valid[3]<=distance_valid; hist_seen[3]<=1; end
                    4: begin hist_level4<=level(distance_mm); hist_valid[4]<=distance_valid; hist_seen[4]<=1; end
                endcase
            end
            if (fast_step_due) begin
                fast_us <= 0;
                fast_steps <= fast_steps - 1'b1;
            end else if (running && !continuous_mode && fast_busy && tick_us)
                fast_us <= fast_us + 1'b1;

            case (system_state)
                SYS_OFF: begin system_state<=SYS_SELF; timer_ms<=0; end
                SYS_SELF: if (tick_ms) begin
                    if (timer_ms == SELF_TEST_MS-1) begin system_state<=SYS_STANDBY; timer_ms<=0; end
                    else timer_ms<=timer_ms+1'b1;
                end
                SYS_STANDBY: if (tick_ms) begin
                    if (timer_ms == STANDBY_MS-1) begin
                        system_state<=SYS_RUN;
                        timer_ms<=0;
                        // The initial 0 degree sample precedes continuous step1.
                        if (continuous_mode && !measure_busy) begin
                            measure_start<=1;
                            waiting_measure<=1;
                        end
                    end else timer_ms<=timer_ms+1'b1;
                end
                SYS_RUN: if (tick_ms) begin
                    if (continuous_mode) begin
                        if (continuous_due) begin
                            timer_ms<=0;
                            pending_continuous<=1;
                        end else timer_ms<=timer_ms+1'b1;
                    end else if (basic_due) begin
                        timer_ms<=0;
                        fast_us<=0;
                        fast_steps<=6'd45;
                        current_valid<=0;
                        current_level<=0;
                        if (waiting_measure && !measure_done) begin
                            measure_cancel<=1;
                            waiting_measure<=0;
                            case (nearest_line(angle_bcd))
                                0: begin hist_valid[0]<=0; hist_seen[0]<=1; end
                                1: begin hist_valid[1]<=0; hist_seen[1]<=1; end
                                2: begin hist_valid[2]<=0; hist_seen[2]<=1; end
                                3: begin hist_valid[3]<=0; hist_seen[3]<=1; end
                                4: begin hist_valid[4]<=0; hist_seen[4]<=1; end
                            endcase
                        end
                    end else begin
                        timer_ms<=timer_ms+1'b1;
                        if (timer_ms == SETTLE_MS-1 && !measure_busy && !waiting_measure) begin
                            measure_start<=1;
                            waiting_measure<=1;
                        end
                    end
                end
            endcase
            // One pending bit bridges the existing 60ms schedule to the
            // already-running 20ms PWM frame. No target or angle queue exists.
            // With the 30ms ultrasonic timeout, a transaction completes within
            // 20ms application delay + 30ms measurement, before the next step.
            if (continuous_apply && !measure_busy && !waiting_measure) begin
                measure_start<=1;
                waiting_measure<=1;
                pending_continuous<=0;
            end
        end
    end
endmodule
