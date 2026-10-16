`timescale 1ns/1ps
module lcd_p2_core #(
    parameter ENABLE_READBACK=0,
    parameter USE_UFM=0,
    parameter MIRROR_X=0,
    parameter [5:0] MIN_RADIUS=6,
    parameter integer RESET_CYCLES=50000,
    parameter integer WAIT_CYCLES=1000000,
    parameter FRACTION_BITS=8
)(
    input wire clk,rst,request,
    input wire [7:0] angle,
    input wire direction_up,
    input wire [5:0] radius,
    input wire radius_valid,
    output wire ready,done,initialized,
    input wire [7:0] data_in,
    output wire [7:0] data_out,
    output wire data_oe,
    output wire lcd_rd_n,lcd_wr_n,lcd_a0,lcd_rst_n,lcd_cs_n
);
    wire bus_ready,bus_done;
    wire [7:0] bus_read_data,init_data,draw_data;
    wire init_request,init_a0,draw_request,draw_read_op,draw_data_op,draw_ready;
    lcd_init #(.RESET_CYCLES(RESET_CYCLES),.WAIT_CYCLES(WAIT_CYCLES)) init(
        clk,rst,bus_ready,bus_done,init_request,init_a0,init_data,lcd_rst_n,initialized,1'b1);
    radar_lcd_ctrl #(.USE_UFM(USE_UFM),.MIRROR_X(MIRROR_X),.MIN_RADIUS(MIN_RADIUS),.FRACTION_BITS(FRACTION_BITS)) draw(
        .clk(clk),.rst(rst || !initialized),.request(request && initialized && ENABLE_READBACK),
        .angle(angle),.direction_up(direction_up),.radius(radius),.radius_valid(radius_valid),
        .ready(draw_ready),.done(done),.bus_request(draw_request),
        .bus_read_op(draw_read_op),.bus_data_op(draw_data_op),.bus_write_data(draw_data),
        .bus_ready(bus_ready),.bus_done(bus_done),.bus_read_data(bus_read_data));
    assign ready=initialized && ENABLE_READBACK && draw_ready;
    lcd_bus #(.ENABLE_READBACK(ENABLE_READBACK)) bus(
        .clk(clk),.rst(rst),.request(initialized ? draw_request : init_request),
        .read_op(initialized && draw_read_op),.data_op(initialized ? draw_data_op : init_a0),
        .write_data(initialized ? draw_data : init_data),.data_in(data_in),
        .data_out(data_out),.data_oe(data_oe),.ready(bus_ready),.done(bus_done),.read_data(bus_read_data),
        .lcd_rd_n(lcd_rd_n),.lcd_wr_n(lcd_wr_n),.lcd_a0(lcd_a0),.lcd_cs_n(lcd_cs_n));
endmodule
