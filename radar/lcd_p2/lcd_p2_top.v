`timescale 1ns/1ps
// Autonomous P2 stimulus. Hardware remains disconnected pending electrical approval.
// Default safe build only initializes/clears; polar drawing requires readback.
module lcd_p2_top #(
    parameter ENABLE_READBACK=0,
    parameter USE_UFM=0,
    parameter MIRROR_X=0,
    parameter integer FRAME_CYCLES=1000000
)(input wire clk,inout wire [7:0] lcd_data,
  output wire lcd_rd_n,lcd_wr_n,lcd_a0,lcd_rst_n,lcd_cs_n,
  output wire [7:0] led);
    wire rst,oe,ready,done,initialized;
    wire [7:0] data_out;
    reg [7:0] angle;
    reg direction_up,pending;
    reg [5:0] radius;
    reg [19:0] frame_timer;
    reset_ctrl reset(clk,rst);
    wire request=ready && !pending && frame_timer==0;
    assign lcd_data=oe ? data_out : 8'bz;
    assign led=angle;
    lcd_p2_core #(.ENABLE_READBACK(ENABLE_READBACK),.USE_UFM(USE_UFM),.MIRROR_X(MIRROR_X)) core(
        .clk(clk),.rst(rst),.request(request),.angle(angle),.direction_up(direction_up),
        .radius(radius),.radius_valid(1'b1),.ready(ready),.done(done),.initialized(initialized),
        .data_in(lcd_data),.data_out(data_out),.data_oe(oe),.lcd_rd_n(lcd_rd_n),
        .lcd_wr_n(lcd_wr_n),.lcd_a0(lcd_a0),.lcd_rst_n(lcd_rst_n),.lcd_cs_n(lcd_cs_n));
    always @(posedge clk) begin
        if(rst) begin angle<=0;direction_up<=1;pending<=0;radius<=8;frame_timer<=0;end
        else begin
            if(frame_timer!=0) frame_timer<=frame_timer-1'b1;
            if(request) begin pending<=1;frame_timer<=FRAME_CYCLES-1;end
            if(done) begin
                pending<=0;
                if(direction_up) begin
                    angle<=angle+1'b1;
                    if(angle==179) direction_up<=0;
                end else begin
                    angle<=angle-1'b1;
                    if(angle==1) direction_up<=1;
                end
                radius<=radius==44 ? 6'd8 : radius+1'b1;
            end
        end
    end
endmodule

// Explicit compilation-only opt-in variants; never program before electrical approval.
module lcd_p2_case_read_test_top(input wire clk,inout wire [7:0] lcd_data,
    output wire lcd_rd_n,lcd_wr_n,lcd_a0,lcd_rst_n,lcd_cs_n,output wire [7:0] led);
    lcd_p2_top #(.ENABLE_READBACK(1),.USE_UFM(0)) test_core(
        clk,lcd_data,lcd_rd_n,lcd_wr_n,lcd_a0,lcd_rst_n,lcd_cs_n,led);
endmodule
module lcd_p2_ufm_read_test_top(input wire clk,inout wire [7:0] lcd_data,
    output wire lcd_rd_n,lcd_wr_n,lcd_a0,lcd_rst_n,lcd_cs_n,output wire [7:0] led);
    lcd_p2_top #(.ENABLE_READBACK(1),.USE_UFM(1)) test_core(
        clk,lcd_data,lcd_rd_n,lcd_wr_n,lcd_a0,lcd_rst_n,lcd_cs_n,led);
endmodule
