`timescale 1ns/1ps
// 50 MHz defaults: setup 80 ns, WR low 120 ns, RD low 200 ns,
// recovery 120 ns. Every read starts with 400 ns of bus release.
// request is accepted only when ready; done is a one-clock pulse.
module lcd_bus #(
    parameter ENABLE_READBACK = 0,
    parameter integer SETUP_CYCLES = 4,
    parameter integer WRITE_CYCLES = 6,
    parameter integer READ_CYCLES = 10,
    parameter integer HOLD_CYCLES = 6,
    parameter integer TURN_CYCLES = 20,
    parameter STABLE_WRITE=0
)(
    input wire clk, rst, request, read_op, data_op,
    input wire [7:0] write_data,
    input wire [7:0] data_in,
    output wire [7:0] data_out,
    output wire data_oe,
    output wire ready,
    output reg done,
    output reg [7:0] read_data,
    output wire lcd_rd_n, lcd_wr_n,
    output reg lcd_a0,
    output wire lcd_cs_n
);
    function integer width;
        input integer n;
        begin width=1; while ((2**width)<n) width=width+1; end
    endfunction
    localparam MAX_A = WRITE_CYCLES > READ_CYCLES ? WRITE_CYCLES : READ_CYCLES;
    localparam MAX_B = SETUP_CYCLES > HOLD_CYCLES ? SETUP_CYCLES : HOLD_CYCLES;
    localparam MAX_C = MAX_A > MAX_B ? MAX_A : MAX_B;
    localparam MAX_N = MAX_C > TURN_CYCLES ? MAX_C : TURN_CYCLES;
    localparam IDLE=0, TURN=1, SETUP=2, ACTIVE=3, HOLD=4;
    reg [2:0] state;
    reg [width(MAX_N)-1:0] timer;
    reg reading;
    reg [7:0] saved_write_data;
    assign data_out=STABLE_WRITE ? write_data : saved_write_data;
    assign ready = state==IDLE;
    assign data_oe = !ENABLE_READBACK || (!reading && state!=IDLE && state!=TURN);
    assign lcd_cs_n = state==IDLE || state==TURN;
    assign lcd_rd_n = !(ENABLE_READBACK && reading && state==ACTIVE);
    assign lcd_wr_n = !(!reading && state==ACTIVE);
    always @(posedge clk) begin
        if (rst) begin
            state<=IDLE; timer<=0; reading<=0; saved_write_data<=0;
            lcd_a0<=0; done<=0; read_data<=0;
        end else begin
            done<=0;
            case(state)
            IDLE: if (request && (!read_op || ENABLE_READBACK)) begin
                reading<=ENABLE_READBACK && read_op;
                if(!STABLE_WRITE) saved_write_data<=write_data;
                lcd_a0<=data_op;
                if (ENABLE_READBACK && read_op) begin state<=TURN; timer<=TURN_CYCLES-1; end
                else begin state<=SETUP; timer<=SETUP_CYCLES-1; end
            end
            TURN: if (timer==0) begin state<=SETUP; timer<=SETUP_CYCLES-1; end else timer<=timer-1'b1;
            SETUP: if (timer==0) begin state<=ACTIVE; timer<=reading ? READ_CYCLES-1 : WRITE_CYCLES-1; end else timer<=timer-1'b1;
            ACTIVE: begin
                // Sample one full clock BEFORE the rising edge of /RD.
                if (ENABLE_READBACK && reading && timer==1) read_data<=data_in;
                if (timer==0) begin state<=HOLD; timer<=HOLD_CYCLES-1; end else timer<=timer-1'b1;
            end
            HOLD: if (timer==0) begin state<=IDLE; done<=1; end else timer<=timer-1'b1;
            default: state<=IDLE;
            endcase
        end
    end
endmodule
