`timescale 1ns/1ps
module minsky_lcd_test_top(
    input wire clk,rst,delay_tick,request,direction_up,radius_valid,
    input wire [11:0] angle_bcd,
    input wire [5:0] radius,
    output wire ready,done,
    output wire [7:0] dropped,
    inout wire [7:0] lcd_data,
    output wire lcd_rd_n,lcd_wr_n,lcd_a0,lcd_rst_n,lcd_cs_n
);
    wire bus_ready,bus_done,initialized,init_request,init_a0,draw_request,draw_read,draw_a0,oe;
    wire [7:0] init_data,draw_data,read_data,data_out;
    lcd_init #(.WAIT_TICK_CYCLES(50000)) init(
      clk,rst,bus_ready,bus_done,init_request,init_a0,init_data,lcd_rst_n,initialized,delay_tick);
    radar_minsky_draw #(.ENABLE_READBACK(1)) draw(
      .clk(clk),.rst(rst || !initialized),.request(request && initialized),
      .angle_bcd(angle_bcd),.direction_up(direction_up),.radius(radius),.radius_valid(radius_valid),
      .ready(ready),.done(done),.dropped(dropped),.bus_request(draw_request),
      .bus_read_op(draw_read),.bus_data_op(draw_a0),.bus_write_data(draw_data),
      .bus_ready(bus_ready),.bus_done(bus_done),.bus_read_data(read_data));
    lcd_bus #(.ENABLE_READBACK(1)) bus(
      .clk(clk),.rst(rst),.request(initialized ? draw_request : init_request),
      .read_op(initialized && draw_read),.data_op(initialized ? draw_a0 : init_a0),
      .write_data(initialized ? draw_data : init_data),.data_in(lcd_data),
      .data_out(data_out),.data_oe(oe),.ready(bus_ready),.done(bus_done),.read_data(read_data),
      .lcd_rd_n(lcd_rd_n),.lcd_wr_n(lcd_wr_n),.lcd_a0(lcd_a0),.lcd_cs_n(lcd_cs_n));
    assign lcd_data=oe ? data_out : 8'bz;
endmodule
