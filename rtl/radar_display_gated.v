`timescale 1ns/1ps
// Immediate SW7 gating belongs to the display interface, beside its scan core.
module radar_display_gated(
 input wire clk,rst,enable,tick_250us,
 input wire [1:0] color_phase,system_state,
 input wire blink_2hz,
 input wire [11:0] angle_bcd,
 input wire [15:0] current_distance_bcd,
 input wire current_valid,
 input wire [2:0] hist_level0,hist_level1,hist_level2,hist_level3,hist_level4,
 input wire [4:0] hist_valid,hist_seen,
 output wire [6:0] seg,
 output wire [7:0] cat_n,row_n,col_r,col_g,
 output wire [2:0] scan_idx
);
 wire [6:0] segments;
 wire [7:0] cats,rows,reds,greens;
 radar_display_shared core(
 .clk(clk),.rst(rst),.enable(enable),.tick_250us(tick_250us),.color_phase(color_phase),
 .system_state(system_state),.blink_2hz(blink_2hz),.angle_bcd(angle_bcd),
 .current_distance_bcd(current_distance_bcd),.current_valid(current_valid),
 .hist_level0(hist_level0),.hist_level1(hist_level1),.hist_level2(hist_level2),
 .hist_level3(hist_level3),.hist_level4(hist_level4),.hist_valid(hist_valid),.hist_seen(hist_seen),
 .seg(segments),.cat_n(cats),.row_n(rows),.col_r(reds),.col_g(greens),.scan_idx(scan_idx));
 assign seg=enable ? segments : 7'b0;
 assign cat_n=enable ? cats : 8'hff;
 assign row_n=enable ? rows : 8'hff;
 assign col_r=enable ? reds : 8'b0;
 assign col_g=enable ? greens : 8'b0;
endmodule
