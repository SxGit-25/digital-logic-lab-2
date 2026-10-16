`timescale 1ns/1ps

module tb_servo_pwm;
    reg clk = 1'b0;
    reg rst = 1'b1;
    reg enable = 1'b0;
    reg [2:0] angle_idx = 3'd0;
    wire servo_out;
    wire angle_applied;
    integer high_count;
    integer i;

    always #5 clk = ~clk;

    servo_pwm dut (
        .clk(clk), .rst(rst), .tick_us(1'b1), .enable(enable),
        .angle_idx(angle_idx), .servo_out(servo_out),
        .angle_applied(angle_applied)
    );

    task count_high;
        input integer expected;
        begin
            while (!servo_out) @(posedge clk);
            high_count = 0;
            while (servo_out) begin
                @(posedge clk); #1;
                high_count = high_count + 1;
            end
            // The task can be entered in the same simulation time slot as
            // the rising edge, so one sampled cycle may already have elapsed.
            if ((high_count != expected) && (high_count != expected - 1)) begin
                $display("FAIL servo pulse: got %0d us expected %0d", high_count, expected);
                $fatal(1);
            end
        end
    endtask

    initial begin
        repeat (3) @(posedge clk);
        rst <= 1'b0;
        @(posedge clk);
        enable <= 1'b1;
        count_high(500);

        // Change the command in the middle of a frame.  The current frame
        // remains 500 us and the next frame adopts 45 degrees.
        repeat (5000) @(posedge clk);
        angle_idx <= 3'd1;
        while (!angle_applied) @(posedge clk);
        count_high(1000);

        enable <= 1'b0;
        @(posedge clk); #1;
        if (servo_out !== 1'b0) begin
            $display("FAIL servo did not stop immediately");
            $fatal(1);
        end
        $display("PASS tb_servo_pwm");
        $finish;
    end
endmodule
