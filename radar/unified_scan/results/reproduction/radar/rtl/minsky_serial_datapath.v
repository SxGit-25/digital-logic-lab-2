`timescale 1ns/1ps
// Command wrapper. A request is accepted only with ready=1. Commands presented
// while busy are ignored; advance may pause an in-flight command without changes.
// 0:c-=s>>>ROT_SHIFT, 1:s+=c>>>ROT_SHIFT,
// 2:s-=c>>>ROT_SHIFT, 3:c+=s>>>ROT_SHIFT,
// 4:x+=c, 5:y+=s, 6:reset_xy, 7:reset_vec.
module minsky_serial_datapath #(
    parameter FRACTION_BITS=17,
    parameter ROT_SHIFT=8,
    parameter [FRACTION_BITS+6:0] XY_INITIAL=(1 << (FRACTION_BITS-1)),
    parameter RESET_DATA=1
)(
    input wire clk,rst,request,
    input wire [2:0] command,
    input wire advance,
    output wire ready,
    output reg done,
    output wire signed [FRACTION_BITS+1:0] c,s,
    output wire signed [FRACTION_BITS+6:0] x_acc,y_acc,
    output wire signed [6:0] x_offset,y_offset
);
    reg busy;
    reg [2:0] active_command;
    reg [4:0] bit_index;
    wire accept=request && !busy;
    wire [2:0] core_command=busy ? active_command : command;
    assign ready=!busy;
    assign x_offset=x_acc[FRACTION_BITS+6:FRACTION_BITS];
    assign y_offset=y_acc[FRACTION_BITS+6:FRACTION_BITS];
    minsky_serial_registers #(.FRACTION_BITS(FRACTION_BITS),.ROT_SHIFT(ROT_SHIFT),.XY_INITIAL(XY_INITIAL),.RESET_DATA(RESET_DATA)) registers(
        .clk(clk),.rst(rst),.begin_command(accept),
        .command(core_command),.step_enable(busy && advance),.bit_index(bit_index),
        .c(c),.s(s),.x_acc(x_acc),.y_acc(y_acc));
    always @(posedge clk) begin
        if(rst) begin busy<=0;done<=0;active_command<=0;bit_index<=0;end
        else begin
            done<=0;
            if(accept) begin
                active_command<=command;bit_index<=0;
                if(command>=6) done<=1;
                else busy<=1;
            end else if(busy && advance) begin
                if(bit_index==(active_command[2] ? FRACTION_BITS+6 : FRACTION_BITS+1)) begin
                    busy<=0;done<=1;
                end else bit_index<=bit_index+1'b1;
            end
        end
    end
endmodule

// Reusable register bank and a single one-bit full adder. A future master
// sequencer may drive begin_command/step_enable/bit_index directly instead of
// retaining the command wrapper. No wide arithmetic exists in this core.
// RESET_DATA=0 requires command7 before vector use and command6 before ray use.
// carry/source_sign are always initialized by begin_command before any step.
module minsky_serial_registers #(
    parameter FRACTION_BITS=17,
    parameter ROT_SHIFT=8,
    parameter [FRACTION_BITS+6:0] XY_INITIAL=(1 << (FRACTION_BITS-1)),
    parameter RESET_DATA=1
)(
    input wire clk,rst,begin_command,
    input wire [2:0] command,
    input wire step_enable,
    input wire [4:0] bit_index,
    output reg signed [FRACTION_BITS+1:0] c,s,
    output reg signed [FRACTION_BITS+6:0] x_acc,y_acc
);
    reg carry,source_sign;
    wire ray_add=command[2];
    wire destination_c=command==0 || command==3;
    wire subtract=command==0 || command==2;
    wire source_bit=ray_add ?
        (bit_index<FRACTION_BITS+2 ? (command[0] ? s[0] : c[0]) : source_sign) :
        (bit_index<FRACTION_BITS+2-ROT_SHIFT ? (destination_c ? s[ROT_SHIFT] : c[ROT_SHIFT]) : source_sign);
    wire destination_bit=ray_add ? (command[0] ? y_acc[0] : x_acc[0]) :
        (destination_c ? c[0] : s[0]);
    // The sole datapath arithmetic expression. Subtraction uses ~source+1.
    wire [1:0] full_sum={1'b0,destination_bit}+{1'b0,(source_bit^subtract)}+carry;
    always @(posedge clk) begin
        if(RESET_DATA && rst) begin
            c<=(1 << FRACTION_BITS);s<=0;x_acc<=XY_INITIAL;y_acc<=XY_INITIAL;
            carry<=0;source_sign<=0;
        end else if(begin_command) begin
            carry<=subtract;
            source_sign<=ray_add ? (command[0] ? s[FRACTION_BITS+1] : c[FRACTION_BITS+1]) :
                (destination_c ? s[FRACTION_BITS+1] : c[FRACTION_BITS+1]);
            if(command==6) begin x_acc<=XY_INITIAL;y_acc<=XY_INITIAL;end
            if(command==7) begin c<=(1 << FRACTION_BITS);s<=0;end
        end else if(step_enable) begin
            carry<=full_sum[1];
            if(!ray_add) begin
                c<={destination_c ? full_sum[0] : c[0],c[FRACTION_BITS+1:1]};
                s<={destination_c ? s[0] : full_sum[0],s[FRACTION_BITS+1:1]};
            end else begin
                if(command[0]) begin
                    y_acc<={full_sum[0],y_acc[FRACTION_BITS+6:1]};
                    if(bit_index<FRACTION_BITS+2) s<={s[0],s[FRACTION_BITS+1:1]};
                end else begin
                    x_acc<={full_sum[0],x_acc[FRACTION_BITS+6:1]};
                    if(bit_index<FRACTION_BITS+2) c<={c[0],c[FRACTION_BITS+1:1]};
                end
            end
        end
    end
endmodule
