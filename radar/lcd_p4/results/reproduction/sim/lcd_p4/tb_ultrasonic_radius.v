`timescale 1ns/1ps
module tb_ultrasonic_radius;
    reg clk = 0;
    reg rst = 1;
    reg tick_us = 1;
    reg start = 0;
    reg cancel = 0;
    reg echo = 0;
    wire [15:0] original_outputs, disabled_outputs, enabled_outputs;
    wire [5:0] radius, radius_disabled;
    wire radius_valid, radius_disabled_valid;
    integer cycle = 0;
    integer checks = 0;
    integer mm_events = 0;
    integer expected_work;
    integer cases = 0;
    reg was_reset = 0;
    always #5 clk = ~clk;

    ultrasonic_legacy legacy (
        .clk(clk), .rst(rst), .tick_us(tick_us), .measure_start(start),
        .cancel(cancel), .echo_async(echo), .trig(original_outputs[15]),
        .measure_busy(original_outputs[14]), .measure_done(original_outputs[13]),
        .distance_valid(original_outputs[12]), .distance_mm(original_outputs[11:0])
    );
    ultrasonic #(.ENABLE_RADIUS(0)) disabled (
        .clk(clk), .rst(rst), .tick_us(tick_us), .measure_start(start),
        .cancel(cancel), .echo_async(echo), .trig(disabled_outputs[15]),
        .measure_busy(disabled_outputs[14]), .measure_done(disabled_outputs[13]),
        .distance_valid(disabled_outputs[12]), .distance_mm(disabled_outputs[11:0]),
        .radius(radius_disabled), .radius_valid(radius_disabled_valid)
    );
    ultrasonic #(.ENABLE_RADIUS(1)) dut (
        .clk(clk), .rst(rst), .tick_us(tick_us), .measure_start(start),
        .cancel(cancel), .echo_async(echo), .trig(enabled_outputs[15]),
        .measure_busy(enabled_outputs[14]), .measure_done(enabled_outputs[13]),
        .distance_valid(enabled_outputs[12]), .distance_mm(enabled_outputs[11:0]),
        .radius(radius), .radius_valid(radius_valid)
    );

    // Independent count of original millimetre increments, sampled before NBA.
    // Arithmetic below is testbench-only; the RTL uses counters/comparators.
    always @(posedge clk) begin
        cycle = cycle + 1;
        if (rst || cancel || ((dut.state == 0) && start) ||
            ((dut.state == 3) && dut.echo_rise)) mm_events = 0;
        else if ((dut.state == 4) && !dut.echo_fall && tick_us &&
                 (dut.budget_us != 29999) && (dut.distance_rem >= 83))
            mm_events = mm_events + 1;
        #1;
        if (rst) was_reset = 1;
        if (was_reset) begin
            checks = checks + 1;
            if ((original_outputs !== disabled_outputs) ||
                (original_outputs !== enabled_outputs)) begin
                $display("FAIL cycle equivalence cycle=%0d old=%h off=%h on=%h",
                         cycle, original_outputs, disabled_outputs, enabled_outputs);
                $fatal(1);
            end
            if ((radius_disabled !== 0) || (radius_disabled_valid !== 0))
                $fatal(1, "disabled radius outputs are not zero");
            expected_work = mm_events / 25;
            if (expected_work > 48) expected_work = 48;
            if ((dut.g_radius.radius_work !== expected_work) ||
                (dut.g_radius.radius_over1200 !== (mm_events > 1200)))
                $fatal(1, "radius accumulator event=%0d work=%0d overflow=%b",
                       mm_events, dut.g_radius.radius_work, dut.g_radius.radius_over1200);
        end
    end

    task pulse_start;
        begin
            @(negedge clk); start = 1;
            @(negedge clk); start = 0;
            if (radius_valid) $fatal(1, "new measurement retained radius_valid");
        end
    endtask
    task finish_case;
        input integer expected_mm;
        input integer expected_valid;
        input integer expected_radius;
        input integer expected_radius_valid;
        begin
            @(posedge enabled_outputs[13]); #2;
            if ((enabled_outputs[11:0] !== expected_mm) ||
                (enabled_outputs[12] !== expected_valid) ||
                (radius !== expected_radius) || (radius_valid !== expected_radius_valid))
                $fatal(1, "result mm=%0d valid=%b radius=%0d rv=%b expected=%0d/%0d/%0d/%0d",
                       enabled_outputs[11:0], enabled_outputs[12], radius, radius_valid,
                       expected_mm, expected_valid, expected_radius, expected_radius_valid);
            cases = cases + 1;
            $display("PASS case=%0d echo_us=%0d mm=%0d valid=%b radius=%0d radius_valid=%b",
                     cases, dut.echo_us, enabled_outputs[11:0], enabled_outputs[12], radius, radius_valid);
            repeat (3) @(negedge clk);
        end
    endtask
    task echo_case;
        input integer width_us;
        input integer expected_mm;
        input integer expected_valid;
        input integer expected_radius;
        input integer expected_radius_valid;
        begin
            pulse_start;
            @(negedge enabled_outputs[15]);
            repeat (10) @(negedge clk);
            echo = 1;
            // Entering COUNT_HIGH consumes one cycle before counting starts.
            repeat (width_us + 1) @(negedge clk);
            echo = 0;
            finish_case(expected_mm, expected_valid, expected_radius, expected_radius_valid);
            if (dut.echo_us != width_us) $fatal(1, "unexpected raw echo duration");
        end
    endtask
    task millimetre_case;
        input integer mm;
        integer width_us;
        integer r;
        begin
            width_us = (100 * mm - 50 + 16) / 17;
            r = mm / 25;
            if (r > 48) r = 48;
            echo_case(width_us, mm, 1, r, mm <= 1200);
        end
    endtask

    initial begin
        repeat (4) @(negedge clk);
        rst = 0;
        echo_case(117, 0, 0, 0, 0);
        echo_case(118, 20, 1, 0, 1);
        millimetre_case(24);
        millimetre_case(25);
        millimetre_case(26);
        millimetre_case(1199);
        millimetre_case(1200);
        millimetre_case(1201);
        echo_case(23529, 4000, 1, 48, 0);
        echo_case(23530, 0, 0, 0, 0);

        pulse_start; // No echo timeout after a nonzero measurement.
        finish_case(0, 0, 0, 0);
        echo = 1;
        repeat (5) @(negedge clk);
        pulse_start; // Echo already high must wait for low and time out.
        finish_case(0, 0, 0, 0);
        echo = 0;
        repeat (5) @(negedge clk);

        pulse_start; // A rising echo that never falls also times out invalid.
        @(negedge enabled_outputs[15]);
        repeat (10) @(negedge clk);
        echo = 1;
        finish_case(0, 0, 0, 0);
        echo = 0;
        repeat (5) @(negedge clk);

        pulse_start; // Cancellation while the accumulated radius is nonzero.
        @(negedge enabled_outputs[15]);
        repeat (10) @(negedge clk);
        echo = 1;
        repeat (8000) @(negedge clk);
        cancel = 1;
        @(negedge clk); cancel = 0; echo = 0;
        #2;
        if (enabled_outputs[14] || enabled_outputs[13] || radius_valid)
            $fatal(1, "cancel failed to clear pending measurement");
        repeat (5) @(negedge clk);
        millimetre_case(25); // Restart must clear previous overflow/counters.

        pulse_start;
        @(negedge enabled_outputs[15]);
        repeat (10) @(negedge clk);
        echo = 1;
        repeat (50) @(negedge clk);
        tick_us = 0; // Paused tick cannot advance either conversion.
        repeat (37) @(negedge clk);
        tick_us = 1;
        repeat (96) @(negedge clk);
        echo = 0;
        finish_case(25, 1, 1, 1);

        $display("PASS tb_ultrasonic_radius cases=%0d cycle_equivalence_checks=%0d baseline=ca8ec99", cases, checks);
        $finish;
    end
    initial begin
        #4000000;
        $fatal(1, "watchdog timeout");
    end
endmodule
