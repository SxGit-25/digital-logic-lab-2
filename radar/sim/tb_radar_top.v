`timescale 1ns/1ps

module tb_radar_top;
    reg clk = 1'b0;
    reg sw7 = 1'b0;
    reg echo = 1'b0;
    wire trig, servo, buzzer;
    wire [15:0] led;
    wire seg_a,seg_b,seg_c,seg_d,seg_e,seg_f,seg_g;
    wire [7:0] cat_n, matrix_row_n, matrix_col_r, matrix_col_g;

    always #5 clk = ~clk;

    radar_top #(
        .CLK_HZ(1_000_000), .SELF_TEST_MS(4), .STANDBY_MS(4),
        .SLOT_MS(10), .SETTLE_MS(1), .SWITCH_MS(1)
    ) dut (
        .clk(clk), .sw7(sw7), .echo(echo), .trig(trig), .servo(servo),
        .buzzer(buzzer), .led(led), .seg_a(seg_a), .seg_b(seg_b),
        .seg_c(seg_c), .seg_d(seg_d), .seg_e(seg_e), .seg_f(seg_f),
        .seg_g(seg_g), .cat_n(cat_n), .matrix_row_n(matrix_row_n),
        .matrix_col_r(matrix_col_r), .matrix_col_g(matrix_col_g)
    );

    initial begin
        repeat (20) @(posedge clk);
        if (cat_n != 8'hFF || matrix_row_n != 8'hFF || led != 16'h0) begin
            $display("FAIL top outputs active while off");
            $fatal(1);
        end

        sw7 <= 1'b1;
        wait (dut.system_state == 2'd1);
        wait (dut.system_state == 2'd2);
        if (!dut.servo_enable) begin
            $display("FAIL top servo disabled in standby");
            $fatal(1);
        end
        wait (dut.system_state == 2'd3);
        wait (trig);
        @(negedge trig);
        repeat (20) @(posedge clk);
        echo <= 1'b1;
        repeat (1000) @(posedge clk);
        echo <= 1'b0;
        wait (dut.current_valid);
        if ((dut.current_distance < 12'd169) || (dut.current_distance > 12'd171)) begin
            $display("FAIL top measured %0d mm", dut.current_distance);
            $fatal(1);
        end

        sw7 <= 1'b0;
        #1;
        if (servo || trig || buzzer || led != 16'h0 || cat_n != 8'hFF ||
            matrix_row_n != 8'hFF) begin
            $display("FAIL top raw switch did not gate outputs");
            $fatal(1);
        end
        $display("PASS tb_radar_top");
        $finish;
    end
endmodule
