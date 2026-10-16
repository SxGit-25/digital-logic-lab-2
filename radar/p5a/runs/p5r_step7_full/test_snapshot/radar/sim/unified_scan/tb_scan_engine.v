`timescale 1ns/1ps
module tb_scan_engine;
    parameter integer PRODUCTION=0;
    parameter integer MODE=0;
    parameter integer HOLD=1;
    parameter integer SKEW=0;
    parameter integer DENSE=0;
    parameter integer DEGREE=1;
    parameter integer STANDBY=PRODUCTION?2000:2;
    localparam SELF=PRODUCTION?2000:2;
    localparam SLOT=PRODUCTION?2000:2;
    localparam SETTLE=PRODUCTION?300:1;
    localparam STEP=PRODUCTION?60:1;
    localparam FAST=PRODUCTION?16:1;
    reg clk=0,rst=1,tick_us=0,tick_ms=0,enable=0;
    wire [1:0] state,oldstate;
    wire servo,serven,ms,mc,step_event,sample_event,fs,fast;
    wire [11:0] angle,sampleangle,current_dist;
    wire up,sampleup,valid;
    wire [2:0] sampleidx,lvl,h0,h1,h2,h3,h4;
    wire [4:0] hv,hs;
    reg busy=0,done=0;
    reg [11:0] distance=600;
    reg dv=1;
    integer response_us=0;
    wire oldms,oldmc,oldserven,oldap,oldservo;
    wire [2:0] oldidx;
    wire oldfs;
    reg oldbusy=0,olddone=0;
    integer oldresponse_us=0;
    integer elapsed_us=0,steps=0,samples=0,commits=0,frames=0,fasts=0;
    integer expected,group,nearest;
    integer intermediates=0;
    time run_time,old_run_time,fast_time,last_sample_time,last_step_time;
    time old_sample_times[0:16];
    reg last_fast=0;
    reg [1:0] last_state=0,last_oldstate=0;

    radar_unified_scan #(.SELF_TEST_MS(SELF),.STANDBY_MS(STANDBY),.SLOT_MS(SLOT),
        .SETTLE_MS(SETTLE),.CONTINUOUS_STEP_MS(STEP),.FAST_STEP_US(FAST),.HOLD_FAST_PWM(HOLD),.CONTINUOUS_DEGREE_STEP(DEGREE)) dut (
        .clk(clk),.rst(rst),.tick_us(tick_us),.tick_ms(tick_ms),.enable(enable),.continuous_mode(MODE!=0),
        .measure_busy(busy),.measure_done(done),.distance_mm(distance),.distance_valid(dv),
        .system_state(state),.servo(servo),.servo_enable(serven),.angle_bcd(angle),.direction_up(up),
        .measure_start(ms),.measure_cancel(mc),.sample_angle_bcd(sampleangle),.sample_direction_up(sampleup),
        .sample_idx(sampleidx),.current_distance(current_dist),.current_valid(valid),.current_level(lvl),
        .hist_level0(h0),.hist_level1(h1),.hist_level2(h2),.hist_level3(h3),.hist_level4(h4),
        .hist_valid(hv),.hist_seen(hs),.step_event(step_event),.sample_event(sample_event),
        .frame_start(fs),.fast_busy(fast));
    radar_unified_scan_verified_degree1 #(.SELF_TEST_MS(SELF),.STANDBY_MS(STANDBY),.SLOT_MS(SLOT),
        .SETTLE_MS(SETTLE),.CONTINUOUS_STEP_MS(STEP),.FAST_STEP_US(FAST),.HOLD_FAST_PWM(HOLD)) verified (
        .clk(clk),.rst(rst),.tick_us(tick_us),.tick_ms(tick_ms),.enable(enable),.continuous_mode(MODE!=0),
        .measure_busy(busy),.measure_done(done),.distance_mm(distance),.distance_valid(dv));
    radar_ctrl_legacy #(.SELF_TEST_MS(SELF),.STANDBY_MS(STANDBY),.SLOT_MS(SLOT),.SETTLE_MS(SETTLE)) oldctrl (
        .clk(clk),.rst(rst),.tick_ms(tick_ms),.system_on(enable),.angle_applied(oldap),
        .measure_busy(oldbusy),.measure_done(olddone),.distance_mm(distance),.distance_valid(dv),
        .system_state(oldstate),.servo_enable(oldserven),.angle_idx(oldidx),.measure_start(oldms),.measure_cancel(oldmc),
        .continuous_mode(1'b0),.continuous_angle(8'd0),.continuous_direction_up(1'b1));
    servo_pwm_legacy #(.SUPPORT_CONTINUOUS(1)) oldpwm (
        .clk(clk),.rst(rst),.tick_us(tick_us),.enable(oldserven),.angle_idx(oldidx),
        .servo_out(oldservo),.angle_applied(oldap),.continuous_mode(1'b0),.sweep_run(oldstate==3),.frame_start(oldfs));

    function integer degrees;
        input [11:0] a;
        begin degrees=a[11:8]*100+a[7:4]*10+a[3:0]; end
    endfunction
    function integer triangle;
        input integer n;
        integer k;
        begin k=n%8; triangle=(k<=4?k:8-k)*45; end
    endfunction
    always @(posedge clk) begin
        done<=0; olddone<=0;
        if(rst || mc) begin busy<=0;response_us=0; end
        else if(ms) begin busy<=1;response_us=5; end
        else if(tick_us && response_us>0) begin
            response_us=response_us-1;
            if(response_us==0) begin busy<=0;done<=1;end
        end
        if(rst || oldmc) begin oldbusy<=0;oldresponse_us=0;end
        else if(oldms) begin oldbusy<=1;oldresponse_us=5;end
        else if(tick_us && oldresponse_us>0) begin
            oldresponse_us=oldresponse_us-1;
            if(oldresponse_us==0) begin oldbusy<=0;olddone<=1;end
        end
        #1;
        if((DEGREE==1 || !MODE) &&
            {dut.system_state,dut.servo,dut.servo_enable,dut.angle_bcd,dut.direction_up,
             dut.measure_start,dut.measure_cancel,dut.sample_angle_bcd,dut.sample_direction_up,dut.sample_idx,
             dut.current_distance,dut.current_valid,dut.current_level,dut.hist_level0,dut.hist_level1,dut.hist_level2,
             dut.hist_level3,dut.hist_level4,dut.hist_valid,dut.hist_seen,dut.step_event,dut.sample_event,dut.frame_start,dut.fast_busy}
             !==
            {verified.system_state,verified.servo,verified.servo_enable,verified.angle_bcd,verified.direction_up,
             verified.measure_start,verified.measure_cancel,verified.sample_angle_bcd,verified.sample_direction_up,verified.sample_idx,
             verified.current_distance,verified.current_valid,verified.current_level,verified.hist_level0,verified.hist_level1,verified.hist_level2,
             verified.hist_level3,verified.hist_level4,verified.hist_valid,verified.hist_seen,verified.step_event,verified.sample_event,verified.frame_start,verified.fast_busy})
            $fatal(1,"experimental parameters changed the verified default/basic behavior");
        if(dut.current_bcd!==0) $fatal(1,"binary distance mode must hold current_bcd zero");
        if(state==3 && last_state!=3) begin run_time=$time;$display("RUN new ns=%0t",$time);end
        if(oldstate==3 && last_oldstate!=3) begin old_run_time=$time;$display("RUN old ns=%0t",$time);end
        last_state=state;last_oldstate=oldstate;
        if(fast && !last_fast) begin
            fast_time=$time; fasts=fasts+1;
            $display("FAST begin slot=%0d ns=%0t frame_us=%0d active_pulse=%0d",fasts,$time,dut.frame_us,dut.active_pulse_us);
            if(SKEW && fasts==1) begin
                dut.local_frame_us=19990;
                verified.frame_us=19990;
                $display("TEST phase injection: frame boundary in 10us while fast walk is active");
            end
        end
        if(!fast && last_fast) begin
            if($time-fast_time != 45*FAST*1000) $fatal(1,"fast duration mismatch");
            $display("FAST end ns=%0t duration_ns=%0d angle=%h command_pulse=%0d",$time,$time-fast_time,angle,dut.command_pulse_us);
        end
        last_fast=fast;
        if(step_event) begin
            steps=steps+1;
            expected=degrees(angle);
            if(angle[3:0]>9 || angle[7:4]>9 || angle[11:8]>1 || expected>180)
                $fatal(1,"invalid BCD degree");
            if(dut.command_pulse_us != 500+(expected*100+4)/9 || dut.pulse_remainder!=(expected*100+4)%9)
                $fatal(1,"pulse quantization drift angle=%0d pulse=%0d remainder=%0d",expected,dut.command_pulse_us,dut.pulse_remainder);
            if(MODE && steps>1 && $time-last_step_time != STEP*1000000) $fatal(1,"continuous step period");
            last_step_time=$time;
        end
        if(fs) begin
            frames=frames+1;
            if(!MODE && state==3 && dut.active_pulse_us!=500 && dut.active_pulse_us!=1000 &&
                dut.active_pulse_us!=1500 && dut.active_pulse_us!=2000 && dut.active_pulse_us!=2500) begin
                intermediates=intermediates+1;
                $display("INTERMEDIATE ns=%0t active_pulse=%0d angle=%h fast=%b",$time,dut.active_pulse_us,angle,fast);
                if(HOLD) $fatal(1,"hold candidate emitted intermediate pulse");
            end
            if(PRODUCTION && !MODE && $time>=run_time+SLOT*1000000 && dut.frame_us==0)
                $display("FRAME ns=%0t active_pulse=%0d old_pulse=%0d",$time,dut.active_pulse_us,oldpwm.pulse_us);
        end
        if(ms) begin
            if(MODE) begin
                expected=((samples*DEGREE)%360)<=180?(samples*DEGREE)%360:360-(samples*DEGREE)%360;
            end else expected=triangle(samples);
            if(degrees(angle)!=expected) $fatal(1,"sample sequence n=%0d got=%h expected=%0d",samples,angle,expected);
            if(MODE && dut.active_pulse_us != dut.command_pulse_us)
                $fatal(1,"continuous sampled a target before its PWM was applied");
            if(!MODE && $time-run_time != (samples*SLOT+SETTLE)*1000000)
                $fatal(1,"basic request not at slot+settle: n=%0d ns=%0t run=%0t",samples,$time,run_time);
            $display("MEASURE new n=%0d ns=%0t offset_ns=%0d angle=%h active_pulse=%0d",samples,$time,$time-run_time,angle,dut.active_pulse_us);
            samples=samples+1;last_sample_time=$time;
        end
        if(oldms && !MODE) $display("MEASURE old ns=%0t offset_ns=%0d idx=%0d",$time,$time-old_run_time,oldidx);
        if(sample_event) begin
            expected=degrees(sampleangle);
            nearest=expected<23?0:expected<68?1:expected<113?2:expected<158?3:4;
            if(sampleidx!=nearest || !valid || current_dist!=600 || lvl!=2 || !hs[nearest] || !hv[nearest])
                $fatal(1,"sample/history commit mismatch angle=%h idx=%0d",sampleangle,sampleidx);
            commits=commits+1;
        end
        // Full BCD round-trip test only: compress the frame boundary interval
        // to 1ms by injecting its terminal state. Production tests retain the
        // real 20ms counter and verify the real 60ms measurement cadence.
        if(!PRODUCTION && MODE && dut.frame_us==999) begin dut.local_frame_us=19999;verified.frame_us=19999;end
    end
    initial begin
        $timeformat(-9,0,"",0);
        // The 50 MHz rising edges retained here have their exact timestamps.
        // After every us tick, retain two extra clocks to settle all registered
        // start/done/state handshakes; omitted clocks have no enabled counters.
        for(elapsed_us=0;elapsed_us<(PRODUCTION?(MODE?4170000:8310000):(MODE?365010:36000));elapsed_us=elapsed_us+1) begin
            if(elapsed_us==2) begin rst=0;enable=1;end
            tick_us=1;tick_ms=(elapsed_us%1000)==999;
            #10;clk=1;#10;clk=0;tick_us=0;tick_ms=0;
            if(DENSE) begin
                repeat(49) begin #10;clk=1;#10;clk=0;end
            end else begin
                repeat(2) begin #10;clk=1;#10;clk=0;end
                #940;
            end
        end
        if(PRODUCTION && samples!=3) $fatal(1,"production sample count %0d",samples);
        if(!PRODUCTION && !MODE && samples!=16) $fatal(1,"basic full sweep sample count %0d",samples);
        if(!PRODUCTION && MODE && samples<361) $fatal(1,"continuous full round sample count %0d",samples);
        if(commits!=samples) $fatal(1,"not every step/sample committed");
        $display("PASS tb_scan_engine production=%0d mode=%0d hold=%0d degree=%0d samples=%0d commits=%0d steps=%0d frames=%0d intermediate_pulses=%0d",PRODUCTION,MODE,HOLD,DEGREE,samples,commits,steps,frames,intermediates);
        $finish;
    end
endmodule
