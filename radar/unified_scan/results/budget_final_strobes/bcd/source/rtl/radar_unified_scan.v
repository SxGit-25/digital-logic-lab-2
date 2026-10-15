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
    parameter integer HOLD_FAST_PWM = 1,
    parameter integer CONTINUOUS_DEGREE_STEP = 1,
    parameter integer DISTANCE_IS_BCD = 0,
    parameter integer USE_GLOBAL_TIMING = 0,
    parameter integer SETTLE_FROM_PWM = 0
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
    output wire [2:0] current_level,
    output reg [2:0] hist_level0, hist_level1, hist_level2,
    output reg [2:0] hist_level3, hist_level4,
    output wire [4:0] hist_valid,
    output reg [4:0] hist_seen,
    output reg step_event, sample_event, frame_start,
    output wire fast_busy,
    input wire [15:0] distance_bcd,
    output reg [15:0] current_bcd,
    output wire measurement_pending,
    input wire [14:0] global_frame_us,
    input wire global_frame_tick
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
    localparam integer FAST_TIMER_MAX = SETTLE_FROM_PWM && SETTLE_MS > FAST_STEP_US ? SETTLE_MS : FAST_STEP_US;
    reg [count_width(FAST_TIMER_MAX)-1:0] fast_us;
    reg [1:0] settle_phase; // 0 inactive, 1 awaiting applied PWM, 2 settling
    reg [5:0] fast_steps;
    reg previous_mode, waiting_measure, pending_continuous;
    reg [2:0] binary_current_level;
    reg [11:0] command_pulse_us, active_pulse_us;
    reg [3:0] pulse_remainder;
    reg [14:0] local_frame_us;
    wire [14:0] frame_us=USE_GLOBAL_TIMING ? global_frame_us : local_frame_us;
    reg was_servo_enabled;
    wire mode_changed = continuous_mode != previous_mode;
    assign measurement_pending=waiting_measure || pending_continuous || measure_start;
    wire running = enable && !mode_changed && system_state == SYS_RUN;
    wire continuous_due = running && continuous_mode && tick_ms &&
                          timer_ms == CONTINUOUS_STEP_MS-1;
    wire basic_due = running && !continuous_mode && tick_ms && timer_ms == SLOT_MS-1;
    wire fast_step_due = running && !continuous_mode && fast_steps != 0 &&
                         tick_us && fast_us == FAST_STEP_US-1;
    wire degree_step = continuous_due || fast_step_due;
    wire frame_latch = servo_enable && (USE_GLOBAL_TIMING ? global_frame_tick : (was_servo_enabled && tick_us && frame_us == 19999));
    wire continuous_apply = running && continuous_mode && frame_latch &&
                            (pending_continuous || continuous_due);
    // Degree2 is an ablation candidate only. Basic always retains degree1.
    wire step_two = CONTINUOUS_DEGREE_STEP == 2 && continuous_mode;
    wire step_to_endpoint = direction_up ? angle_bcd == (step_two ? 12'h178 : 12'h179) :
                                         angle_bcd == (step_two ? 12'h002 : 12'h001);
    wire [3:0] decimal_delta = direction_up ? (step_two ? 4'd2 : 4'd1) : (step_two ? 4'd14 : 4'd15);
    wire [3:0] decimal_limit = direction_up ? 4'd9 : 4'd0;
    wire [3:0] decimal_wrap = direction_up ? 4'd0 : 4'd9;
    wire units_carry = direction_up ? (step_two ? angle_bcd[3] : angle_bcd[3:0] == 9) :
                                     (step_two ? angle_bcd[3:1] == 0 : angle_bcd[3:0] == 0);
    wire [3:0] units_wrap = step_two ? (direction_up ? {3'b000,angle_bcd[0]} : {3'b100,angle_bcd[0]}) : decimal_wrap;
    wire large_pulse_step = direction_up ? (step_two ? pulse_remainder >= 7 : pulse_remainder == 8) :
                                          (step_two ? pulse_remainder < 2 : pulse_remainder == 0);
    wire [11:0] pulse_delta = direction_up ?
        (step_two ? (large_pulse_step ? 12'd23 : 12'd22) : (large_pulse_step ? 12'd12 : 12'd11)) :
        (step_two ? (large_pulse_step ? 12'hfe9 : 12'hfea) : (large_pulse_step ? 12'hff4 : 12'hff5));
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
    function [2:0] level_bcd;
        input [15:0] bcd;
        begin
            // Hundreds digit divided by two gives all four threshold bins.
            level_bcd=bcd[15:12]!=0 ? 3'd1 : 3'd5-bcd[11:9];
        end
    endfunction
    wire [2:0] measured_level = DISTANCE_IS_BCD ? level_bcd(distance_bcd) : level(distance_mm);
    // BCD input is the ultrasonic committed snapshot, not its working counter.
    // Retaining another three-bit snapshot would duplicate the same information.
    assign current_level = DISTANCE_IS_BCD ? (current_valid ? measured_level : 3'd0) : binary_current_level;
    // Level zero encodes an already-measured invalid/expired line. The seen
    // bits separately distinguish startup's green guide from an invalid gap.
    assign hist_valid = {hist_level4!=0,hist_level3!=0,hist_level2!=0,hist_level1!=0,hist_level0!=0};
    wire [2:0] history_level_write = history_commit && distance_valid ? measured_level : 3'd0;
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
    assign servo = servo_enable && (!USE_GLOBAL_TIMING || was_servo_enabled) && frame_us < active_pulse_us;
    assign fast_busy = fast_steps != 0;
    wire history_commit = system_state == SYS_RUN && measure_done && waiting_measure;
    wire history_cancel = basic_due && waiting_measure && !measure_done;
    wire history_write = history_commit || history_cancel;

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
                if (!units_carry)
                    angle_bcd[3:0] <= angle_bcd[3:0] + decimal_delta;
                else begin
                    angle_bcd[3:0] <= units_wrap;
                    if (angle_bcd[7:4] != decimal_limit)
                        angle_bcd[7:4] <= angle_bcd[7:4] + (direction_up ? 4'd1 : 4'd15);
                    else begin
                        angle_bcd[7:4] <= decimal_wrap;
                        angle_bcd[11:8] <= {3'b000,!angle_bcd[8]};
                    end
                end
                if (step_to_endpoint) direction_up <= !direction_up;
                command_pulse_us <= next_pulse_us;
                if (direction_up) begin
                    if (large_pulse_step) begin
                        pulse_remainder <= step_two ? pulse_remainder - 4'd7 : 4'd0;
                    end else begin
                        pulse_remainder <= pulse_remainder + (step_two ? 4'd2 : 4'd1);
                    end
                end else begin
                    if (large_pulse_step) begin
                        pulse_remainder <= step_two ? pulse_remainder + 4'd7 : 4'd8;
                    end else begin
                        pulse_remainder <= pulse_remainder - (step_two ? 4'd2 : 4'd1);
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
            local_frame_us <= 0;
            active_pulse_us <= 12'd500;
            was_servo_enabled <= 0;
            frame_start <= 0;
        end else if(USE_GLOBAL_TIMING) begin
            frame_start<=0;
            if(global_frame_tick) begin
                was_servo_enabled<=1;frame_start<=1;
                if(!HOLD_FAST_PWM || continuous_mode || !fast_busy)
                    active_pulse_us<=continuous_due ? next_pulse_us : command_pulse_us;
            end
        end else begin
            was_servo_enabled <= 1;
            frame_start <= 0;
            if (!was_servo_enabled) begin
                local_frame_us <= 0;
                active_pulse_us <= command_pulse_us;
                frame_start <= 1;
            end else if (tick_us) begin
                if (frame_us == 19999) begin
                    local_frame_us <= 0;
                    frame_start <= 1;
                    if (!HOLD_FAST_PWM || continuous_mode || !fast_busy)
                        active_pulse_us <= continuous_due ? next_pulse_us : command_pulse_us;
                end else local_frame_us <= frame_us + 1'b1;
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
            settle_phase <= 0;
            waiting_measure <= 0;
            pending_continuous <= 0;
            measure_start <= 0;
            measure_cancel <= 1;
            sample_angle_bcd <= 0;
            sample_direction_up <= 1;
            sample_idx <= 0;
            current_distance <= 0;
            current_bcd <= 0;
            current_valid <= 0;
            binary_current_level <= 0;
            hist_level0 <= 0; hist_level1 <= 0; hist_level2 <= 0;
            hist_level3 <= 0; hist_level4 <= 0;
            hist_seen <= 0;
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
            if (history_commit) begin
                waiting_measure <= 0;
                current_distance <= DISTANCE_IS_BCD ? 12'd0 : distance_mm;
                current_bcd <= DISTANCE_IS_BCD ? distance_bcd : 16'd0;
                current_valid <= distance_valid;
                binary_current_level <= distance_valid ? measured_level : 0;
                sample_event <= 1;

            end
            if (history_write) begin
                // A pending transaction was tagged before this slot's fast walk.
                // Expiring it addresses that same sample, so one decoder suffices.
                if (sample_idx==0) begin hist_level0<=history_level_write;hist_seen[0]<=1;end
                if (sample_idx==1) begin hist_level1<=history_level_write;hist_seen[1]<=1;end
                if (sample_idx==2) begin hist_level2<=history_level_write;hist_seen[2]<=1;end
                if (sample_idx==3) begin hist_level3<=history_level_write;hist_seen[3]<=1;end
                if (sample_idx==4) begin hist_level4<=history_level_write;hist_seen[4]<=1;end
            end
            if (tick_ms) timer_ms<=timer_ms+1'b1;
            if (SETTLE_FROM_PWM && running && !continuous_mode) begin
                if(settle_phase==1 && frame_latch && !fast_busy) begin
                    settle_phase<=2;fast_us<=0;
                end else if(settle_phase==2 && tick_ms) begin
                    if(fast_us==SETTLE_MS-1) begin
                        settle_phase<=0;
                        if(!measure_busy && !waiting_measure)begin measure_start<=1;waiting_measure<=1;end
                    end else fast_us<=fast_us+1'b1;
                end
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

                end
                SYS_STANDBY: if (tick_ms) begin
                    if (timer_ms == STANDBY_MS-1) begin
                        system_state<=SYS_RUN;
                        timer_ms<=0;
                        if(SETTLE_FROM_PWM) begin settle_phase<=2;fast_us<=0;end
                        // The initial 0 degree sample precedes continuous step1.
                        if (continuous_mode && !measure_busy) begin
                            measure_start<=1;
                            waiting_measure<=1;
                        end
                    end
                end
                SYS_RUN: if (tick_ms) begin
                    if (continuous_mode) begin
                        if (continuous_due) begin
                            timer_ms<=0;
                            pending_continuous<=1;
                        end
                    end else if (basic_due) begin
                        timer_ms<=0;
                        fast_us<=0;
                        fast_steps<=6'd45;
                        if(SETTLE_FROM_PWM) settle_phase<=1;
                        current_valid<=0;
                        binary_current_level<=0;
                        if (waiting_measure && !measure_done) begin
                            measure_cancel<=1;
                            waiting_measure<=0;

                        end
                    end else begin
                        if (!SETTLE_FROM_PWM && timer_ms == SETTLE_MS-1 && !measure_busy && !waiting_measure) begin
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
