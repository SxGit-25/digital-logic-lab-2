`timescale 1ns/1ps

// Open-loop sweep: pulse width changes only at PWM frame boundaries.
// active_pulse_us is the applied command, not measured mechanical position.
module servo_sweep #(
    parameter integer FRAME_US = 20000,
    parameter integer MIN_PULSE_US = 500,
    parameter integer MAX_PULSE_US = 2500,
    parameter integer STEP_US = 5,
    parameter integer STARTUP_FRAMES = 50
) (
    input wire clk,
    input wire rst,
    input wire tick_us,
    input wire enable,
    output wire servo_out,
    output reg [11:0] active_pulse_us,
    output reg direction_up,
    output reg frame_start
);
    function integer count_width;
        input integer count;
        integer value;
        begin
            value = count - 1;
            count_width = 0;
            while (value > 0) begin
                count_width = count_width + 1;
                value = value >> 1;
            end
            if (count_width < 1) count_width = 1;
        end
    endfunction

    localparam [11:0] MIN_PULSE = MIN_PULSE_US[11:0];
    localparam [11:0] MAX_PULSE = MAX_PULSE_US[11:0];
    localparam [11:0] STEP = STEP_US[11:0];
    reg [count_width(FRAME_US)-1:0] frame_us;
    reg [count_width(STARTUP_FRAMES)-1:0] startup_count;
    reg running;

    // Gate off immediately; restart is synchronized to tick_us below.
    assign servo_out = enable && !rst && running && (frame_us < active_pulse_us);

    // synthesis translate_off
    initial begin
        if (MIN_PULSE_US < 1 || MAX_PULSE_US > 4095 ||
            MAX_PULSE_US <= MIN_PULSE_US || FRAME_US <= MAX_PULSE_US ||
            STEP_US < 1 || STEP_US > MAX_PULSE_US - MIN_PULSE_US ||
            STARTUP_FRAMES < 0) begin
            $display("ERROR: invalid servo_sweep parameters");
            $finish;
        end
    end
    // synthesis translate_on

    always @(posedge clk) begin
        if (rst || !enable) begin
            frame_us <= 0;
            startup_count <= 0;
            active_pulse_us <= MIN_PULSE;
            direction_up <= 1'b1;
            running <= 1'b0;
            frame_start <= 1'b0;
        end else begin
            frame_start <= 1'b0;
            if (tick_us) begin
                if (!running) begin
                    running <= 1'b1;
                    frame_us <= 0;
                    frame_start <= 1'b1;
                end else if (frame_us == FRAME_US - 1) begin
                    frame_us <= 0;
                    frame_start <= 1'b1;
                    if (STARTUP_FRAMES > 1 && startup_count < STARTUP_FRAMES - 1) begin
                        startup_count <= startup_count + 1'b1;
                    end else if (direction_up) begin
                        if (active_pulse_us >= MAX_PULSE - STEP) begin
                            active_pulse_us <= MAX_PULSE;
                            direction_up <= 1'b0;
                        end else begin
                            active_pulse_us <= active_pulse_us + STEP;
                        end
                    end else begin
                        if (active_pulse_us <= MIN_PULSE + STEP) begin
                            active_pulse_us <= MIN_PULSE;
                            direction_up <= 1'b1;
                        end else begin
                            active_pulse_us <= active_pulse_us - STEP;
                        end
                    end
                end else begin
                    frame_us <= frame_us + 1'b1;
                end
            end
        end
    end
endmodule
