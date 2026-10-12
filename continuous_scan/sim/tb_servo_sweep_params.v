`timescale 1ns/1ps
module tb_servo_sweep_params;
    reg clk=0,rst=1,enable=0,tick_us=0;
    wire servo_out,direction_up,frame_start;
    wire [11:0] active_pulse_us;
    integer frame_no=0,expected,k,j;
    servo_sweep #(.FRAME_US(20),.MIN_PULSE_US(3),.MAX_PULSE_US(10),.STEP_US(4),.STARTUP_FRAMES(0)) dut
        (.clk(clk),.rst(rst),.tick_us(tick_us),.enable(enable),.servo_out(servo_out),
         .active_pulse_us(active_pulse_us),.direction_up(direction_up),.frame_start(frame_start));
    always #5 clk=~clk;
    task step;
        input tick;
        begin @(negedge clk); tick_us=tick; @(posedge clk); #1; end
    endtask
    initial begin
        step(0); step(0);
        @(negedge clk); rst=0;enable=1;
        repeat(3) begin step(0); if(servo_out !== 0 || frame_start !== 0) $fatal(1,"started without tick_us"); end
        step(1);
        // Uneven final increment must saturate (3->7->10->6->3).
        repeat(13) begin
            case(frame_no%4) 0:expected=3; 1:expected=7; 2:expected=10; 3:expected=6; endcase
            if(frame_start !== 1 || active_pulse_us !== expected) $fatal(1,"frame %0d got %0d expected %0d",frame_no,active_pulse_us,expected);
            for(k=0;k<20;k=k+1) begin
                if(servo_out !== (k<expected)) $fatal(1,"wrong PWM at microsecond %0d",k);
                repeat(3) begin
                    step(0);
                    if(frame_start !== 0) $fatal(1,"frame_start must be one system clock");
                    if(servo_out !== (k<expected) || active_pulse_us !== expected) $fatal(1,"state changed without tick_us");
                end
                step(1);
            end
            frame_no=frame_no+1;
        end
        @(negedge clk);enable=0; #1;
        if(servo_out !== 0) $fatal(1,"asynchronous output disable");
        step(0);
        @(negedge clk);enable=1;
        step(0); if(servo_out !== 0) $fatal(1,"restart without tick");
        step(1); if(active_pulse_us !== 3 || frame_start !== 1) $fatal(1,"restart not at MIN");
        $display("PASS tb_servo_sweep_params: STARTUP_FRAMES=0, saturation, sparse ticks, immediate gating, restart");
        $finish;
    end
    initial begin #100000; $fatal(1,"timeout"); end
endmodule
