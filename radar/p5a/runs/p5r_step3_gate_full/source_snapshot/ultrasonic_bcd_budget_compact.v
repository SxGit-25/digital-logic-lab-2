`timescale 1ns/1ps
// 50 MHz: one integer divide-by-294 tick is approximately one millimetre.
// The phase is ZERO on the synchronized echo rising edge (no half-tick bias).
// radius is the working radius, invalid during a measurement, and is held
// after completion until the next start. distance_bcd is a committed snapshot.
module ultrasonic_bcd_budget_compact #(
    parameter integer TRIG_US=15,
    parameter integer TIMEOUT_US=30000,
    parameter integer ENABLE_RADIUS=1,
    parameter integer USE_MS_TIMEOUT=1
)(
    input wire clk,rst,tick_us,measure_start,cancel,echo_async,tick_ms,
    output reg trig,
    output wire measure_busy,
    output reg measure_done,
    output reg [15:0] distance_bcd,
    output reg distance_valid,
    output wire [2:0] distance_level,
    output reg [5:0] radius,
    output reg radius_valid
);
    function integer width;
        input integer n;
        begin width=0;for(n=n-1;n>0;n=n>>1) width=width+1;
              if(width<1)width=1;end
    endfunction
    localparam IDLE=0,TRIGGER=1,WAIT_LOW=2,WAIT_RISE=3,COUNT=4,COMMIT=5,FINISH=6;
    reg [2:0] state;
    reg echo_meta,echo_sync,echo_prev;
    localparam TIMEOUT_TICKS=USE_MS_TIMEOUT ? (TIMEOUT_US+999)/1000+1 : TIMEOUT_US;
    reg [width(TIMEOUT_TICKS)-1:0] timer;
    reg [8:0] phase;
    reg [15:0] work;

    reg carry;
    wire digit_nine=work[3:0]==9;
    wire [3:0] next_digit=carry ? (digit_nine ? 4'd0 : work[3:0]+1'b1) : work[3:0];


    wire rise=echo_sync&&!echo_prev;
    wire fall=!echo_sync&&echo_prev;
    wire timeout_tick=USE_MS_TIMEOUT ? tick_ms : tick_us;
    wire expired=timeout_tick&&timer==TIMEOUT_TICKS-1;
    wire mm_tick=phase==293;
    wire range_ok=(work[15:8]!=0||work[7:4]>=2)&&
        (work[15:12]<4||(work[15:12]==4&&work[11:0]==0));
    assign measure_busy=state!=IDLE;
    // Packed BCD has the same ordering as its represented unsigned integer.
    assign distance_level=!distance_valid ? 0 : distance_bcd[15:12]!=0 ? 1 :
        3'd5-distance_bcd[11:9];
    always @(posedge clk) begin
        if(rst) begin echo_meta<=0;echo_sync<=0;echo_prev<=0;end
        else begin echo_meta<=echo_async;echo_sync<=echo_meta;echo_prev<=echo_sync;end
    end
    always @(posedge clk) begin
        if(rst) begin
            state<=IDLE;trig<=0;measure_done<=0;
            distance_valid<=0;
            radius_valid<=0;
        end else begin
            measure_done<=0;
            // Rotate all four decimal digits through one 4-bit incrementer.
            // A complete increment takes four clocks out of each 294 clocks.
            if((state==COUNT||state==FINISH)&&phase<4) begin
                work<={next_digit,work[15:4]};

                carry<=carry&&digit_nine;
            end
            if(ENABLE_RADIUS&&(state==COUNT||state==FINISH)&&phase==4&&radius!=48&&
               ((work[7:0]==8'h00&&work[15:8]!=0)||work[7:0]==8'h25||
                work[7:0]==8'h50||work[7:0]==8'h75))radius<=radius+1'b1;
            if(cancel) begin
                state<=IDLE;trig<=0;distance_valid<=0;radius_valid<=0;
            end else case(state)
                IDLE:if(measure_start) begin
                    state<=TRIGGER;trig<=1;timer<=0;phase<=0;distance_valid<=0;
                    radius_valid<=0;radius<=0;work<=0;carry<=0;
                end
                TRIGGER:if(tick_us) begin
                    if(phase==TRIG_US-1) begin
                        trig<=0;timer<=0;state<=echo_sync?WAIT_LOW:WAIT_RISE;
                    end else phase<=phase+1'b1;
                end
                WAIT_LOW,WAIT_RISE:begin
                    if(timeout_tick)timer<=timer+1'b1;
                    if(expired) state<=COMMIT;
                    else if(state==WAIT_LOW&&!echo_sync)state<=WAIT_RISE;
                    else if(state==WAIT_RISE&&rise)begin state<=COUNT;phase<=0;end
                end
                COUNT:begin
                    if(timeout_tick)timer<=timer+1'b1;
                    if(expired) begin work<=0;state<=COMMIT;end
                    else if(fall)begin state<=FINISH;phase<=phase+1'b1;end
                    else if(mm_tick) begin
                        phase<=0;
                        carry<=1;
                    end else phase<=phase+1'b1;
                end
                FINISH:begin phase<=phase+1'b1;if(phase>=4)state<=COMMIT;end
                COMMIT:begin
                    distance_bcd<=work;
                    distance_valid<=range_ok&&!echo_sync;
                    radius_valid<=ENABLE_RADIUS&&range_ok&&!echo_sync&&(work<=16'h1200);
                    measure_done<=1;state<=IDLE;
                end
                default:state<=IDLE;
            endcase
        end
    end
endmodule
