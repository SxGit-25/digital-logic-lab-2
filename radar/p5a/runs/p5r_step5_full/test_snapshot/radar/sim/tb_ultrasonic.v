`timescale 1ns/1ps

module tb_ultrasonic;
    reg clk = 1'b0;
    reg rst = 1'b1;
    reg start = 1'b0;
    reg cancel = 1'b0;
    reg echo = 1'b0;
    wire trig;
    wire busy;
    wire done;
    wire [11:0] distance;
    wire valid;

    always #5 clk = ~clk;

    ultrasonic #(.TIMEOUT_US(2000)) dut (
        .clk(clk), .rst(rst), .tick_us(1'b1),
        .measure_start(start), .cancel(cancel), .echo_async(echo),
        .trig(trig), .measure_busy(busy), .measure_done(done),
        .distance_mm(distance), .distance_valid(valid)
    );

    task pulse_start;
        begin
            @(posedge clk); start <= 1'b1;
            @(posedge clk); start <= 1'b0;
        end
    endtask

    initial begin
        repeat (3) @(posedge clk);
        rst <= 1'b0;

        pulse_start;
        @(negedge trig);
        repeat (20) @(posedge clk);
        echo <= 1'b1;
        repeat (1000) @(posedge clk);
        echo <= 1'b0;
        @(posedge done); #1;
        if (!valid || (distance < 12'd169) || (distance > 12'd171)) begin
            $display("FAIL ultrasonic normal result: valid=%0d distance=%0d", valid, distance);
            $fatal(1);
        end

        pulse_start;
        @(posedge done); #1;
        if (valid) begin
            $display("FAIL ultrasonic no-echo timeout marked valid");
            $fatal(1);
        end

        echo <= 1'b1;
        repeat (4) @(posedge clk);
        pulse_start;
        @(posedge done); #1;
        if (valid) begin
            $display("FAIL ultrasonic pre-high echo marked valid");
            $fatal(1);
        end
        echo <= 1'b0;

        pulse_start;
        wait (busy);
        @(posedge clk); cancel <= 1'b1;
        @(posedge clk); cancel <= 1'b0;
        @(posedge clk); #1;
        if (busy || done) begin
            $display("FAIL ultrasonic cancel left pending state");
            $fatal(1);
        end

        $display("PASS tb_ultrasonic");
        $finish;
    end
endmodule
