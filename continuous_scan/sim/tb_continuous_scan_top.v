`timescale 1ns/1ps
module tb_continuous_scan_top;
    reg clk=0, sw7=0;
    wire servo,trig,buzzer;
    wire [15:0] led;
    wire [6:0] seg;
    wire [7:0] cat_n,matrix_row_n,matrix_col_r,matrix_col_g;
    integer i, highs;
    continuous_scan_top #(.CLK_HZ(1000000),.SWITCH_MS(2),.STARTUP_FRAMES(1)) dut
        (.clk(clk),.sw7(sw7),.servo(servo),.trig(trig),.buzzer(buzzer),.led(led),
         .seg_a(seg[6]),.seg_b(seg[5]),.seg_c(seg[4]),.seg_d(seg[3]),.seg_e(seg[2]),.seg_f(seg[1]),.seg_g(seg[0]),
         .cat_n(cat_n),.matrix_row_n(matrix_row_n),.matrix_col_r(matrix_col_r),.matrix_col_g(matrix_col_g));
    always #500 clk=~clk;
    task clocks;
        input integer n;
        integer j;
        begin for(j=0;j<n;j=j+1) begin @(posedge clk); #1; end end
    endtask
    initial begin
        clocks(25);
        if(servo !== 0 || led !== 0) $fatal(1,"disabled power-up");
        if(trig !== 0 || buzzer !== 0 || seg !== 0 || cat_n !== 8'hff || matrix_row_n !== 8'hff || matrix_col_r !== 0 || matrix_col_g !== 0)
            $fatal(1,"unrelated peripherals not inactive");
        @(negedge clk);sw7=1;
        clocks(500);
        if(servo !== 0 || led !== 0) $fatal(1,"switch filter bypassed");
        wait(servo===1); #1;
        if(led !== 16'h0003) $fatal(1,"LED enabled/increasing indication");
        highs=0;
        while(servo===1) begin highs=highs+1;clocks(1);end
        if(highs!=500) $fatal(1,"top first pulse width %0d",highs);
        wait(servo===1); #1;
        if(dut.u_sweep.active_pulse_us !== 505) $fatal(1,"top failed to sweep");
        @(negedge clk);sw7=0; #1;
        if(servo !== 0 || led !== 0) $fatal(1,"raw switch off must gate immediately");
        clocks(3000);
        @(negedge clk);sw7=1;
        wait(servo===1); #1;
        if(dut.u_sweep.active_pulse_us !== 500) $fatal(1,"top restart not at MIN");
        $display("PASS tb_continuous_scan_top: reset, switch filter, PWM, immediate disable, restart, inactive peripherals, LEDs");
        $finish;
    end
    initial begin #40000000; $fatal(1,"timeout");end
endmodule
