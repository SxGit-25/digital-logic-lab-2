`timescale 1ns/1ps
// Safe default: physical data port is output-only and always driven.
module lcd_p1_write_top(input wire clk, output wire [7:0] lcd_data,
 output wire lcd_rd_n,lcd_wr_n,lcd_a0,lcd_rst_n,lcd_cs_n,
 output wire [7:0] led);
 wire rst,oe,finished;
 reset_ctrl reset(clk,rst);
 lcd_p1_core core(clk,rst,8'b0,lcd_data,oe,lcd_rd_n,lcd_wr_n,lcd_a0,lcd_rst_n,lcd_cs_n,led,finished);
endmodule
// Explicit opt-in test artifact. DO NOT program before electrical approval.
module lcd_p1_read_top(input wire clk, inout wire [7:0] lcd_data,
 output wire lcd_rd_n,lcd_wr_n,lcd_a0,lcd_rst_n,lcd_cs_n,
 output wire [7:0] led);
 wire rst,oe,finished;
 wire [7:0] data_out;
 reset_ctrl reset(clk,rst);
 assign lcd_data=oe ? data_out : 8'bz;
 lcd_p1_core #(.ENABLE_READBACK(1)) core(clk,rst,lcd_data,data_out,oe,
  lcd_rd_n,lcd_wr_n,lcd_a0,lcd_rst_n,lcd_cs_n,led,finished);
endmodule
