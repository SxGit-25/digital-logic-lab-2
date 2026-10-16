`timescale 1ns/1ps
`include "vectors_count.vh"
module tb_p5_ui_columns;
    reg [1:0] kind, char_index;
    reg [2:0] font_col, level;
    reg [11:0] angle_bcd;
    reg [15:0] distance_bcd;
    reg mode_continuous;
    reg [4:0] level_offset;
    wire [7:0] column_byte;
    reg [7:0] expected;
    reg [51:0] vectors [0:`VECTOR_COUNT-1];
    integer i;
    p5_ui_columns dut(.*);
    initial begin
        $readmemh("vectors.mem", vectors);
        for(i=0;i<`VECTOR_COUNT;i=i+1) begin
            {kind,char_index,font_col,angle_bcd,distance_bcd,mode_continuous,
             level,level_offset,expected}=vectors[i];
            #1;
            if(column_byte!==expected) $fatal(1,"vector %d kind=%d char=%d col=%d got=%h expected=%h",i,kind,char_index,font_col,column_byte,expected);
        end
        $display("PASS UI columns Python vectors=%0d",`VECTOR_COUNT);
        $finish;
    end
endmodule
