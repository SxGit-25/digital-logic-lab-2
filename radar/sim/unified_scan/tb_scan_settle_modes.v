`timescale 1ns/1ps
module tb_scan_settle_modes;
    reg clk=0;always #10 clk=~clk;
    reg rst=1;
    integer us=0;
    reg [14:0] frame_us=0;
    wire tick_ms=(us%1000)==999;
    wire frame_tick=frame_us==19999;
    wire [1:0] state0,state1;
    wire start0,start1;
    reg done0=0,done1=0;
    always @(posedge clk)begin done0<=start0;done1<=start1;end
    wire [11:0] angle0,angle1;
    wire servo0,servo1;
    integer origin=-1,n0=0,n1=0,offset,expect_offset;
    always @(posedge clk) begin
        if(rst)begin us<=0;frame_us<=0;end
        else begin us<=us+1;if(frame_tick)frame_us<=0;else frame_us<=frame_us+1'b1;end
    end
    radar_unified_scan #(.SELF_TEST_MS(20),.STANDBY_MS(20),.USE_GLOBAL_TIMING(1),.SETTLE_FROM_PWM(0)) slot_based(
        .clk(clk),.rst(rst),.tick_us(1'b1),.tick_ms(tick_ms),.enable(1'b1),.continuous_mode(1'b0),
        .measure_busy(1'b0),.measure_done(done0),.distance_mm(12'd0),.distance_valid(1'b0),
        .system_state(state0),.measure_start(start0),.angle_bcd(angle0),.servo(servo0),
        .global_frame_us(frame_us),.global_frame_tick(frame_tick));
    radar_unified_scan #(.SELF_TEST_MS(20),.STANDBY_MS(20),.USE_GLOBAL_TIMING(1),.SETTLE_FROM_PWM(1)) pwm_based(
        .clk(clk),.rst(rst),.tick_us(1'b1),.tick_ms(tick_ms),.enable(1'b1),.continuous_mode(1'b0),
        .measure_busy(1'b0),.measure_done(done1),.distance_mm(12'd0),.distance_valid(1'b0),
        .system_state(state1),.measure_start(start1),.angle_bcd(angle1),.servo(servo1),
        .global_frame_us(frame_us),.global_frame_tick(frame_tick));
    always @(negedge clk) if(!rst)begin
        if(state0==3&&origin<0)begin origin=us;$display("RUN us=%0d",us);end
        if(state0!==state1||angle0!==angle1||servo0!==servo1)$fatal(1,"Settle option changed scan/PWM");
        if(start0)begin
            offset=us-origin;expect_offset=n0*2000000+300000;
            if(offset!=expect_offset)$fatal(1,"Slot settle sample %0d at %0d expected %0d",n0,offset,expect_offset);
            $display("SLOT sample=%0d offset_us=%0d",n0,offset);n0=n0+1;
        end
        if(start1)begin
            offset=us-origin;expect_offset=n1*2000000+300000+(n1==0?0:20000);
            if(offset!=expect_offset)$fatal(1,"PWM settle sample %0d at %0d expected %0d",n1,offset,expect_offset);
            $display("PWM sample=%0d offset_us=%0d",n1,offset);n1=n1+1;
        end
        if(n0==3&&n1==3)begin $display("PASS SETTLE_FROM_PWM first0=300ms following=320ms, shared timing scan/PWM identical");$finish;end
    end
    initial begin repeat(3)@(negedge clk);rst=0;#100000000;$fatal(1,"watchdog");end
endmodule
