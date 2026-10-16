`timescale 1ns/1ps
// ISOLATED EXPERIMENT, 50 MHz only. The legacy measurement path is unchanged.
// One 170-kHz tick represents 1 mm: 50 MHz * 17 / 5000 = 170000 Hz.
// DIVIDER_MODE=1 instead uses 50 MHz / 294 = 170068.027... Hz.
module ultrasonic_bcd_experiment #(
    parameter integer TRIG_US=15,
    parameter integer TIMEOUT_US=30000,
    parameter integer ENABLE_RADIUS=1,
    parameter integer DIVIDER_MODE=0,
    parameter integer RESET_PHASE_ON_ECHO=1,
    parameter integer ROUND_NEAREST=1
)(
    input wire clk,rst,tick_us,measure_start,cancel,echo_async,
    output reg trig,
    output wire measure_busy,
    output reg measure_done,
    output reg [15:0] distance_bcd,
    output reg distance_valid,
    output reg [2:0] distance_level,
    output reg [5:0] radius,
    output reg radius_valid
);
    function integer count_width;
        input integer count;
        integer rest;
        begin
            rest=count-1;count_width=0;
            while(rest>0) begin count_width=count_width+1;rest=rest>>1;end
            if(count_width<1) count_width=1;
        end
    endfunction
    function [15:0] bcd_increment;
        input [15:0] value;
        begin
            bcd_increment=value;
            if(value[3:0]!=9) bcd_increment[3:0]=value[3:0]+1'b1;
            else begin
                bcd_increment[3:0]=0;
                if(value[7:4]!=9) bcd_increment[7:4]=value[7:4]+1'b1;
                else begin
                    bcd_increment[7:4]=0;
                    if(value[11:8]!=9) bcd_increment[11:8]=value[11:8]+1'b1;
                    else begin
                        bcd_increment[11:8]=0;
                        bcd_increment[15:12]=value[15:12]+1'b1;
                    end
                end
            end
        end
    endfunction
    function [2:0] level_of_bcd;
        input [15:0] value;
        begin
            if(value>=16'h0800) level_of_bcd=1;
            else if(value>=16'h0600) level_of_bcd=2;
            else if(value>=16'h0400) level_of_bcd=3;
            else if(value>=16'h0200) level_of_bcd=4;
            else level_of_bcd=5;
        end
    endfunction
    localparam IDLE=0,TRIGGER=1,WAIT_LOW=2,WAIT_RISE=3,COUNT_HIGH=4,CONVERT=5,DONE=6;
    reg [2:0] state;
    reg echo_meta,echo_sync,echo_prev;
    reg [count_width(TRIG_US)-1:0] trigger_us;
    reg [count_width(TIMEOUT_US)-1:0] budget_us;
    reg [15:0] bcd_work;
    wire echo_rise=echo_sync && !echo_prev;
    wire echo_fall=!echo_sync && echo_prev;
    wire echo_start=state==WAIT_RISE && echo_rise;
    wire count_clock=state==COUNT_HIGH && !echo_fall &&
                     !(tick_us && budget_us==TIMEOUT_US-1);
    wire mm_tick;
    assign measure_busy=state!=IDLE && state!=DONE;

    // COUNT_HIGH excludes the synchronized rising-edge clock itself. Preload
    // one clock increment in addition to half a tick, so a width of N clocks
    // gives round(N*17/5000), or round(N/294), rather than round((N-1)*rate).
    generate
        if(DIVIDER_MODE==0) begin : g_fractional
            localparam [12:0] PRELOAD=(ROUND_NEAREST ? 2500 : 0)+17;
            reg [12:0] phase;
            assign mm_tick=phase>=13'd4983;
            always @(posedge clk) begin
                if(rst) phase<=0;
                else if(RESET_PHASE_ON_ECHO && echo_start) phase<=PRELOAD;
                else if(!RESET_PHASE_ON_ECHO || count_clock) begin
                    if(mm_tick) phase<=phase-13'd4983;
                    else phase<=phase+13'd17;
                end
            end
        end else begin : g_integer
            localparam [8:0] PRELOAD=(ROUND_NEAREST ? 147 : 0)+1;
            reg [8:0] phase;
            assign mm_tick=phase==9'd293;
            always @(posedge clk) begin
                if(rst) phase<=0;
                else if(RESET_PHASE_ON_ECHO && echo_start) phase<=PRELOAD;
                else if(!RESET_PHASE_ON_ECHO || count_clock) begin
                    if(mm_tick) phase<=0;
                    else phase<=phase+1'b1;
                end
            end
        end
    endgenerate

    wire bcd_range_valid=bcd_work>=16'h0020 && bcd_work<=16'h4000;
    generate
        if(ENABLE_RADIUS) begin : g_radius
            reg [4:0] mod25;
            reg [5:0] work;
            reg over1200;
            always @(posedge clk) begin
                if(rst) begin
                    radius<=0;radius_valid<=0;mod25<=0;work<=0;over1200<=0;
                end else if(cancel || (state==IDLE && measure_start) || echo_start) begin
                    radius_valid<=0;mod25<=0;work<=0;over1200<=0;
                end else if(count_clock && mm_tick) begin
                    if(work==48) over1200<=1;
                    else if(mod25==24) begin mod25<=0;work<=work+1'b1;end
                    else mod25<=mod25+1'b1;
                end else if(state==CONVERT) begin
                    if(bcd_range_valid && !echo_sync) begin
                        radius<=work;radius_valid<=!over1200;
                    end else begin radius<=0;radius_valid<=0;end
                end
            end
        end else begin : g_no_radius
            always @(posedge clk) begin radius<=0;radius_valid<=0;end
        end
    endgenerate
    always @(posedge clk) begin
        if(rst) begin echo_meta<=0;echo_sync<=0;echo_prev<=0;end
        else begin echo_meta<=echo_async;echo_sync<=echo_meta;echo_prev<=echo_sync;end
    end
    always @(posedge clk) begin
        if(rst) begin
            state<=IDLE;trig<=0;measure_done<=0;distance_bcd<=0;
            distance_valid<=0;distance_level<=0;trigger_us<=0;budget_us<=0;bcd_work<=0;
        end else begin
            measure_done<=0;
            if(cancel) begin
                state<=IDLE;trig<=0;distance_valid<=0;distance_level<=0;
                trigger_us<=0;budget_us<=0;bcd_work<=0;
            end else case(state)
                IDLE:begin
                    trig<=0;
                    if(measure_start) begin
                        state<=TRIGGER;trig<=1;distance_valid<=0;distance_level<=0;
                        trigger_us<=0;budget_us<=0;bcd_work<=0;
                    end
                end
                TRIGGER:if(tick_us) begin
                    if(trigger_us==TRIG_US-1) begin
                        trig<=0;trigger_us<=0;budget_us<=0;
                        state<=echo_sync ? WAIT_LOW : WAIT_RISE;
                    end else trigger_us<=trigger_us+1'b1;
                end
                WAIT_LOW:begin
                    if(!echo_sync) state<=WAIT_RISE;
                    else if(tick_us) begin
                        if(budget_us==TIMEOUT_US-1) state<=CONVERT;
                        else budget_us<=budget_us+1'b1;
                    end
                end
                WAIT_RISE:begin
                    if(echo_rise) begin bcd_work<=0;state<=COUNT_HIGH;end
                    else if(tick_us) begin
                        if(budget_us==TIMEOUT_US-1) state<=CONVERT;
                        else budget_us<=budget_us+1'b1;
                    end
                end
                COUNT_HIGH:begin
                    if(echo_fall) state<=CONVERT;
                    else if(tick_us && budget_us==TIMEOUT_US-1) state<=CONVERT;
                    else begin
                        if(tick_us) budget_us<=budget_us+1'b1;
                        // Saturation preserves invalidity even after a long echo.
                        if(mm_tick && bcd_work!=16'h4001) bcd_work<=bcd_increment(bcd_work);
                    end
                end
                CONVERT:begin
                    if(bcd_range_valid && !echo_sync) begin
                        distance_bcd<=bcd_work;distance_valid<=1;
                        distance_level<=level_of_bcd(bcd_work);
                    end else begin distance_bcd<=0;distance_valid<=0;distance_level<=0;end
                    state<=DONE;
                end
                DONE:begin measure_done<=1;state<=IDLE;end
                default:state<=IDLE;
            endcase
        end
    end
endmodule
