`timescale 1ns/1ps
module tb_scan_control;
    reg clk=0; always #10 clk=~clk;
    reg rst=1,enable=0,mode=0;
    reg tick_us=0,tick_ms=0;
    integer divider=0,microseconds=0;
    reg busy=0,done=0,dv=0;
    reg [11:0] mm=0;
    wire [1:0] state;
    wire servo,start,cancel,commit,valid,fast;
    wire [11:0] angle,current_mm,sampleangle;
    wire [2:0] level,h0,h1,h2,idx;
    wire [4:0] seen,hvalid;
    always @(posedge clk) begin
        tick_us<=0;tick_ms<=0;
        if(rst) begin divider<=0;microseconds<=0;end
        else if(divider==49) begin
            divider<=0;tick_us<=1;
            if(microseconds==999) begin microseconds<=0;tick_ms<=1;end
            else microseconds<=microseconds+1;
        end else divider<=divider+1;
    end
    radar_unified_scan #(.SELF_TEST_MS(1),.STANDBY_MS(1),.SLOT_MS(2),.SETTLE_MS(1),.FAST_STEP_US(1)) dut(
        .clk(clk),.rst(rst),.tick_us(tick_us),.tick_ms(tick_ms),.enable(enable),.continuous_mode(mode),
        .measure_busy(busy),.measure_done(done),.distance_mm(mm),.distance_valid(dv),
        .system_state(state),.servo(servo),.angle_bcd(angle),.measure_start(start),.measure_cancel(cancel),
        .sample_angle_bcd(sampleangle),.sample_idx(idx),.current_distance(current_mm),.current_valid(valid),
        .current_level(level),.hist_level0(h0),.hist_level1(h1),.hist_level2(h2),
        .hist_valid(hvalid),.hist_seen(seen),.sample_event(commit),.fast_busy(fast));
    task reply;
        input [11:0] result;
        input result_valid;
        begin
            @(negedge clk);busy=1;
            repeat(100) @(negedge clk);
            busy=0;mm=result;dv=result_valid;done=1;
            @(negedge clk);done=0;
            #1;
        end
    endtask
    initial begin
        repeat(5) @(negedge clk);rst=0;enable=1;
        @(posedge start); reply(900,0);
        if(valid || level!=0 || current_mm!=900 || seen!=1 || hvalid!=0 || h0!=0 || sampleangle!=0)
            // Zero history level now encodes invalid; visible blank is unchanged.
            $fatal(1,"invalid sample history contract");
        @(posedge start); reply(200,1);
        if(!valid || level!=4 || current_mm!=200 || seen!=3 || hvalid!=2 || h1!=4 || sampleangle!=12'h045 || idx!=1)
            $fatal(1,"valid sample history contract");
        @(posedge start);
        @(negedge clk);busy=1;
        @(posedge cancel);#1;
        if(!seen[2] || hvalid[2] || valid || !fast)
            $fatal(1,"unfinished basic sample was not cancelled/expired at slot boundary");
        @(negedge clk);busy=0;mode=1;
        @(posedge clk);#1;
        if(state!=0 || angle!=0 || seen!=0 || !cancel || servo)
            $fatal(1,"mode switch must cancel, clear history and restart at zero");
        wait(state==3);
        @(negedge clk);enable=0;
        #1;if(servo) $fatal(1,"disable did not gate servo immediately");
        @(posedge clk);#1;
        if(state!=0 || !cancel || seen!=0 || valid || dut.pending_continuous)
            $fatal(1,"off cleanup contract");
        $display("PASS tb_scan_control full50MHz invalid_result/valid_result/history/slot_expiry_cancel/mode_restart/disable");
        $finish;
    end
    initial begin #20000000;$fatal(1,"control watchdog");end
endmodule
