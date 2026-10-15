`timescale 1ns/1ps
module tb_servo_optimized #(parameter integer UNIT5=1);
    reg clk=0;
    always #5 clk=~clk;
    reg rst=1, tick=1, enable=0, mode=0, run=0;
    reg [2:0] idx=0;
    wire [23:0] old0, new0, old1, new1;
    integer checks=0;
    integer i,j,n,width,observed,expected;
    integer rng=32'h12345678;

    servo_pwm_legacy #(.SUPPORT_CONTINUOUS(0)) legacy0 (
        .clk(clk),.rst(rst),.tick_us(tick),.enable(enable),.angle_idx(idx),
        .continuous_mode(mode),.sweep_run(run),.servo_out(old0[23]),
        .angle_applied(old0[22]),.continuous_angle(old0[21:14]),
        .continuous_angle_bcd(old0[13:2]),.direction_up(old0[1]),.frame_start(old0[0]));
    servo_pwm #(.SUPPORT_CONTINUOUS(0),.USE_5US_UNITS(UNIT5)) dut0 (
        .clk(clk),.rst(rst),.tick_us(tick),.enable(enable),.angle_idx(idx),
        .continuous_mode(mode),.sweep_run(run),.servo_out(new0[23]),
        .angle_applied(new0[22]),.continuous_angle(new0[21:14]),
        .continuous_angle_bcd(new0[13:2]),.direction_up(new0[1]),.frame_start(new0[0]));
    servo_pwm_legacy #(.SUPPORT_CONTINUOUS(1)) legacy1 (
        .clk(clk),.rst(rst),.tick_us(tick),.enable(enable),.angle_idx(idx),
        .continuous_mode(mode),.sweep_run(run),.servo_out(old1[23]),
        .angle_applied(old1[22]),.continuous_angle(old1[21:14]),
        .continuous_angle_bcd(old1[13:2]),.direction_up(old1[1]),.frame_start(old1[0]));
    servo_pwm #(.SUPPORT_CONTINUOUS(1),.USE_5US_UNITS(UNIT5)) dut1 (
        .clk(clk),.rst(rst),.tick_us(tick),.enable(enable),.angle_idx(idx),
        .continuous_mode(mode),.sweep_run(run),.servo_out(new1[23]),
        .angle_applied(new1[22]),.continuous_angle(new1[21:14]),
        .continuous_angle_bcd(new1[13:2]),.direction_up(new1[1]),.frame_start(new1[0]));
    always @(posedge clk) begin
        #1;
        checks=checks+1;
        if(old0 !== new0 || old1 !== new1)
            $fatal(1,"cycle=%0d legacy0=%h new0=%h legacy1=%h new1=%h",checks,old0,new0,old1,new1);
        if ({legacy1.sweep_pulse_us,legacy1.angle_phase} !==
            {dut1.sweep_pulse_us,dut1.angle_phase})
            $fatal(1,"internal sweep state mismatch cycle=%0d",checks);
        if (legacy1.frame_us !== dut1.frame_us)
            $fatal(1,"internal frame microseconds mismatch cycle=%0d",checks);
    end

    initial begin
        repeat(3) @(negedge clk);
        rst=0;
        for(i=0;i<120000;i=i+1) begin
            @(negedge clk);
            rng=rng*1664525+1013904223;
            tick=(rng & 7)!=0;
            idx=(rng>>12)&7;
            enable=(i%27000)>20;
            mode=(i%33000)>100;
            run=(i%31000)>50;
            rst=(i%19000)==0;
        end
        @(negedge clk); rst=1;tick=1;enable=0;
        repeat(2) @(negedge clk);
        rst=0;enable=1;mode=1;run=1;
        @(posedge clk); #2;
        for(i=0;i<=800;i=i+1) begin
            n=(i<=400)?i:800-i;
            expected=(n*9+10)/20;
            width=500+5*n;
            if(new1[21:14]!==expected ||
                (new1[13:10]*100+new1[9:6]*10+new1[5:2])!=expected ||
                new1[1] !== (i<400 || i==800))
                $fatal(1,"frame=%0d angle/BCD/direction mismatch",i);
            observed=0;
            for(j=0;j<20000;j=j+1) begin
                if(new1[23]) observed=observed+1;
                @(posedge clk); #2;
            end
            if(observed!=width) $fatal(1,"frame=%0d pulse width=%0d expected=%0d",i,observed,width);
        end
        $display("PASS tb_servo_optimized baseline=f4507a8 unit5=%0d param0/1 all_outputs_cycle_checks=%0d random_cycles=120000 sweep_frames=801 width=500..2500 up_frames=400 down_frames=400",UNIT5,checks);
        $finish;
    end
endmodule
