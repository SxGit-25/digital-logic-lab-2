`timescale 1ns/1ps
// One externally timed scan index drives both displays. Color PWM advances once
// per complete eight-row frame, so every physical LED receives all four phases.
module radar_display_shared (
    input wire clk, rst, enable, tick_250us,
    input wire [1:0] color_phase,
    input wire [1:0] system_state,
    input wire blink_2hz,
    input wire [11:0] angle_bcd,
    input wire [15:0] current_distance_bcd,
    input wire current_valid,
    input wire [2:0] hist_level0, hist_level1, hist_level2,
    input wire [2:0] hist_level3, hist_level4,
    input wire [4:0] hist_valid, hist_seen,
    output reg [6:0] seg,
    output reg [7:0] cat_n, row_n, col_r, col_g,
    output reg [2:0] scan_idx
);
    reg [1:0] blank_stage;
    reg [3:0] digit;
    reg [7:0] red_pixels, green_pixels;
    reg [4:0] red_rays, green_rays;
    reg [2:0] color;
    integer i;
    reg [14:0] levels;

    function [6:0] decode;
        input [3:0] code;
        begin
            case(code)
                0:decode=7'b1111110; 1:decode=7'b0110000;
                2:decode=7'b1101101; 3:decode=7'b1111001;
                4:decode=7'b0110011; 5:decode=7'b1011011;
                6:decode=7'b1011111; 7:decode=7'b1110000;
                8:decode=7'b1111111; 9:decode=7'b1111011;
                10:decode=7'b0000001; default:decode=0;
            endcase
        end
    endfunction
    function red_on;
        input [2:0] c;
        input [1:0] p;
        begin
            case(c)
                2:red_on=(p==0); 3:red_on=(p<2);
                4:red_on=(p<3); 5:red_on=1;
                default:red_on=0;
            endcase
        end
    endfunction
    function green_on;
        input [2:0] c;
        input [1:0] p;
        begin
            case(c)
                1:green_on=1; 2:green_on=(p!=0);
                3:green_on=(p>=2); 4:green_on=(p==3);
                default:green_on=0;
            endcase
        end
    endfunction
    function [7:0] raster;
        input [4:0] rays;
        input [2:0] row;
        input center;
        begin
            case(row)
                0:raster={4'b0,rays[2],3'b0};
                1:raster={1'b0,rays[1],2'b0,rays[2],2'b0,rays[3]};
                2:raster={2'b0,rays[1],1'b0,rays[2],1'b0,rays[3],1'b0};
                3:raster={3'b0,rays[1],rays[2],rays[3],2'b0};
                4:raster={1'b0,{3{rays[0]}},center,{3{rays[4]}}};
                default:raster=0;
            endcase
        end
    endfunction
    always @* begin
        case(scan_idx)
            0:digit=current_distance_bcd[3:0];
            1:digit=current_distance_bcd[7:4];
            2:digit=current_distance_bcd[11:8];
            3:digit=current_distance_bcd[15:12];
            4:digit=15;
            5:digit=angle_bcd[3:0];
            6:digit=angle_bcd[7:4];
            7:digit=angle_bcd[11:8];
        endcase
        if (scan_idx<4 && (!current_valid || system_state==2)) digit=10;
        if (scan_idx>4 && system_state==2) digit=0;
        if (system_state==0) digit=15;
        if (system_state==1) digit=blink_2hz ? 8:15;
        levels={hist_level4,hist_level3,hist_level2,hist_level1,hist_level0};
        red_rays=0; green_rays=0; color=0;
        for(i=0;i<5;i=i+1) begin
            color=levels[i*3+:3];
            if (!hist_seen[i] || system_state==2) color=1;
            else if (!hist_valid[i]) color=0;
            red_rays[i]=red_on(color,color_phase);
            green_rays[i]=green_on(color,color_phase);
        end
        red_pixels=raster(red_rays,scan_idx,1'b0);
        green_pixels=raster(green_rays,scan_idx,1'b1);
        if(system_state==0 || (system_state==1 && !blink_2hz)) begin
            red_pixels=0; green_pixels=0;
        end else if(system_state==1) begin
            red_pixels={8{color_phase<2}};
            green_pixels={8{color_phase>=2}};
        end
    end
    always @(posedge clk) begin
        if(rst || !enable) begin
            scan_idx<=0; blank_stage<=1;
            seg<=0; cat_n<=255; row_n<=255; col_r<=0; col_g<=0;
        end else if (tick_250us) begin
            // Turn both selectors off before changing index or display data.
            cat_n<=255; row_n<=255; scan_idx<=scan_idx+1'b1;
            blank_stage<=1;
        end else if(blank_stage==1) begin
            seg<=decode(digit); col_r<=red_pixels; col_g<=green_pixels;
            blank_stage<=2;
        end else if(blank_stage==2) begin
            cat_n<=~(8'b1<<scan_idx); row_n<=~(8'b1<<scan_idx);
            blank_stage<=0;
        end
    end
endmodule
