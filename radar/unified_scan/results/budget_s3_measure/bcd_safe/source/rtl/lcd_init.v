`timescale 1ns/1ps
// Exclusive ownership of lcd_bus until initialized. 8 pages x 132 columns.
module lcd_init #(
    parameter [7:0] CONTRAST=8'h1c,
    parameter integer RESET_CYCLES=50000,
    parameter integer WAIT_CYCLES=1000000,
    parameter integer WAIT_TICK_CYCLES=1
)(
    input wire clk, rst, bus_ready, bus_done,
    output reg request,
    output reg data_op,
    output reg [7:0] write_data,
    output wire lcd_rst_n,
    output wire initialized,
    input wire delay_tick
);
    function integer width;
        input integer n;
        begin width=1; while ((2**width)<n) width=width+1; end
    endfunction
    // A shared coarse tick may have arbitrary phase. One extra interval
    // ensures the requested minimum even if its first tick is immediate.
    localparam RESET_COUNT=WAIT_TICK_CYCLES==1 ? RESET_CYCLES : (RESET_CYCLES+WAIT_TICK_CYCLES-1)/WAIT_TICK_CYCLES+1;
    localparam WAIT_COUNT=WAIT_TICK_CYCLES==1 ? WAIT_CYCLES : (WAIT_CYCLES+WAIT_TICK_CYCLES-1)/WAIT_TICK_CYCLES+1;
    localparam N=WAIT_COUNT>RESET_COUNT ? WAIT_COUNT : RESET_COUNT;
    wire wait_tick=WAIT_TICK_CYCLES==1 || delay_tick;
    localparam RESET=0, WAIT_RESET=1, COMMAND=2, WAIT_POWER=3,
        PAGE=4, COL_H=5, COL_L=6, CLEAR=7, ON=8, FINISHED=9;
    reg [3:0] state;
    reg [width(N>132 ? N : 132)-1:0] timer;
    // Eight init commands and eight clear pages are disjoint phases. The
    // command index naturally wraps to page zero after command seven.
    reg [2:0] index;
    wire [2:0] page=index;
    reg pending;
    assign lcd_rst_n=state!=RESET;
    assign initialized=state==FINISHED;
    always @* begin
        request=!pending && bus_ready && (state==COMMAND || (state>=PAGE && state<=ON));
        data_op=state==CLEAR;
        write_data=0;
        case(state)
        COMMAND: case(index)
            0:write_data=8'ha2; 1:write_data=8'ha0; 2:write_data=8'hc8;
            3:write_data=8'h2f; 4:write_data=8'h24; 5:write_data=8'h81;
            6:write_data=CONTRAST; 7:write_data=8'h40;
            default:write_data=0;
        endcase
        PAGE:write_data=8'hb0|{5'b0,page};
        COL_H:write_data=8'h10;
        COL_L:write_data=8'h00;
        ON:write_data=8'haf;
        default:write_data=0;
        endcase
    end
    always @(posedge clk) begin
        if(rst) begin state<=RESET; timer<=RESET_COUNT-1; index<=0; pending<=0; end
        else begin
            if(request) pending<=1;
            if(bus_done) pending<=0;
            case(state)
            RESET: if(wait_tick) begin if(timer==0) begin state<=WAIT_RESET; timer<=WAIT_COUNT-1; end else timer<=timer-1'b1; end
            WAIT_RESET, WAIT_POWER: if(wait_tick) begin if(timer==0) state<=COMMAND; else timer<=timer-1'b1; end
            COMMAND: if(bus_done) begin
                index<=index+1'b1;
                if(index==3) begin state<=WAIT_POWER; timer<=WAIT_COUNT-1; end
                else if(index==7) state<=PAGE;
            end
            PAGE:if(bus_done) state<=COL_H;
            COL_H:if(bus_done) state<=COL_L;
            // The reset/power delay counter is idle while clearing. Reuse
            // it for the 132 byte count instead of a separate incrementer.
            COL_L:if(bus_done) begin state<=CLEAR; timer<=131; end
            CLEAR:if(bus_done) begin
                if(timer==0) begin
                    if(page==7) state<=ON;
                    else begin index<=index+1'b1; state<=PAGE; end
                end else timer<=timer-1'b1;
            end
            ON:if(bus_done) state<=FINISHED;
            default:begin end
            endcase
        end
    end
endmodule
