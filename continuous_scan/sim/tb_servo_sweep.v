`timescale 1ns/1ps
module tb_servo_sweep;
    reg clk=0, rst=1, enable=0;
    wire servo_out, direction_up, frame_start;
    wire [11:0] active_pulse_us;
    integer frame_no=0, expected=500, high_count=0, period_count=0;
    integer samples=0;
    servo_sweep dut(.clk(clk),.rst(rst),.tick_us(1'b1),.enable(enable),
        .servo_out(servo_out),.active_pulse_us(active_pulse_us),
        .direction_up(direction_up),.frame_start(frame_start));
    // Each simulation clock represents one microsecond; default 20,000-us
    // frame and 500..2500-us pulses are tested without shrinking parameters.
    always #500 clk=~clk;
    task sample;
        begin @(posedge clk); #1; end
    endtask
    task check_frame;
        input integer width;
        integer k;
        begin
            if (frame_start !== 1 || active_pulse_us !== width || servo_out !== 1)
                $fatal(1,"frame %0d start: flag=%b width=%0d expected=%0d out=%b",frame_no,frame_start,active_pulse_us,width,servo_out);
            high_count=0;
            for(k=0;k<20000;k=k+1) begin
                if(active_pulse_us !== width) $fatal(1,"pulse command changed within frame");
                if(servo_out !== (k<width)) $fatal(1,"frame %0d sample %0d PWM=%b width=%0d",frame_no,k,servo_out,width);
                if(k!=0 && frame_start !== 0) $fatal(1,"frame_start longer than one clock");
                if(servo_out) high_count=high_count+1;
                sample;
            end
            if(high_count != width || frame_start !== 1) $fatal(1,"incorrect pulse duration or 20-ms period");
            frame_no=frame_no+1;
        end
    endtask
    initial begin
        repeat(3) sample;
        @(negedge clk); rst=0; enable=1;
        sample;
        // First 50 frames park at MIN; frames 50..449 increase to MAX;
        // frames 450..849 decrease to MIN, without duplicate endpoint dwell.
        while(frame_no<852) begin
            if(frame_no<50) expected=500;
            else if(frame_no<450) expected=500+(frame_no-49)*5;
            else if(frame_no<850) expected=2500-(frame_no-449)*5;
            else expected=500+(frame_no-849)*5;
            if(direction_up !== ((frame_no<449)||(frame_no>=849))) $fatal(1,"wrong sweep direction frame %0d",frame_no);
            check_frame(expected);
        end
        @(negedge clk); enable=0; #1;
        if(servo_out !== 0) $fatal(1,"disable failed immediate output gating");
        sample;
        if(active_pulse_us !== 500) $fatal(1,"disable failed reset to MIN");
        @(negedge clk); enable=1;
        sample;
        frame_no=0;
        repeat(50) check_frame(500);
        check_frame(505);
        $display("PASS tb_servo_sweep: full 0->180->0 traversal, exact PWM/period, 50-frame startup, disable/restart");
        $finish;
    end
    initial begin #19000000000; $fatal(1,"timeout"); end
endmodule
