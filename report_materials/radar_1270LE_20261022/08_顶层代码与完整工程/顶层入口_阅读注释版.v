// REPORT READING COPY: comments added; use 完整工程 for the compiled inputs.
// Quartus top entity: radar_unified_bcd_top. QSF sets P5_UFM/P5_UFM_BYTE/
// P5_INVERT/P5_BEAM to 1; parameter defaults alone are not production settings.
// clk: 50 MHz. sw7: system enable; sw6: basic/continuous mode; echo: sonar input.
// lcd_data: bidirectional 8080 bus. Peripheral pin numbers are in the QSF.
// ENABLE_READBACK=1; KEEP_END_BATCH=1; MEASUREMENT_BCD=1.
module radar_unified_bcd_top #(parameter SETTLE_FROM_PWM=0, P5_UFM=0, P5_UFM_BYTE=0, P5_INVERT=0, P5_BEAM=0)(input wire clk,sw7,echo,sw6,inout wire [7:0] lcd_data,output wire trig,servo,buzzer,output wire [15:0] led,output wire seg_a,seg_b,seg_c,seg_d,seg_e,seg_f,seg_g,output wire [7:0] cat_n,matrix_row_n,matrix_col_r,matrix_col_g,output wire lcd_rd_n,lcd_wr_n,lcd_a0,lcd_rst_n,lcd_cs_n);
radar_unified_top #(.ENABLE_READBACK(1),.KEEP_END_BATCH(1),.MEASUREMENT_BCD(1),.SETTLE_FROM_PWM(SETTLE_FROM_PWM),.P5_UFM(P5_UFM),.P5_UFM_BYTE(P5_UFM_BYTE),.P5_INVERT(P5_INVERT),.P5_BEAM(P5_BEAM)) system(
.clk(clk),
.sw7(sw7),
.echo(echo),
.sw6(sw6),
.lcd_data(lcd_data),
.trig(trig),
.servo(servo),
.buzzer(buzzer),
.led(led),
.seg_a(seg_a),
.seg_b(seg_b),
.seg_c(seg_c),
.seg_d(seg_d),
.seg_e(seg_e),
.seg_f(seg_f),
.seg_g(seg_g),
.cat_n(cat_n),
.matrix_row_n(matrix_row_n),
.matrix_col_r(matrix_col_r),
.matrix_col_g(matrix_col_g),
.lcd_rd_n(lcd_rd_n),
.lcd_wr_n(lcd_wr_n),
.lcd_a0(lcd_a0),
.lcd_rst_n(lcd_rst_n),
.lcd_cs_n(lcd_cs_n));
endmodule
