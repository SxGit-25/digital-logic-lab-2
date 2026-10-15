`timescale 1ns/1ps
// Experimental replacement for bridge/ray/LUT: one microsequencer drives a
// shared bit-serial ALU and the existing LCD bus. No request queue/backpressure.
// A busy request is dropped and counted; the next accepted BCD angle resyncs
// the persistent Minsky vector by exact forward/inverse degree microsteps.
module radar_minsky_draw #(
    parameter ENABLE_READBACK=0,
    parameter KEEP_END_BATCH=1
)(
    input wire clk,rst,request,
    input wire [11:0] angle_bcd,
    input wire direction_up,
    input wire [5:0] radius,
    input wire radius_valid,
    output wire ready,
    output reg done,
    output reg [7:0] dropped,
    output wire bus_request,bus_read_op,bus_data_op,
    output reg [7:0] bus_write_data,
    input wire bus_ready,bus_done,
    input wire [7:0] bus_read_data
);
    localparam IDLE=0,ORIENT=1,DEGREE=2,ROT_BEGIN=3,ROT_BITS=4,
      RAY_RESET=5,PIXEL=6,ADD_BEGIN=7,ADD_BITS=8,RMW=9,AFTER_RAY=10;
    reg [3:0] state;
    reg [11:0] original_angle,ray_angle,vector_angle;
    reg [4:0] phase;
    reg rotate_up,second_op,axis;
    reg [2:0] micro_left;
    reg [4:0] bit_index;
    reg erase;
    reg [3:0] flush_left;
    reg [5:0] target_radius,step;
    reg target_valid;
    reg [2:0] transaction;
    reg pending;
    wire signed [18:0] c,s;
    wire signed [23:0] x_acc,y_acc;
    wire [6:0] column={~x_acc[23],x_acc[22:17]};
    wire [5:0] pixel_y=~y_acc[22:17];
    wire [7:0] mask=8'b1<<pixel_y[2:0];
    wire ring=step==16 || step==32 || step==48;
    wire selected=step>=6 && (erase ? !ring : (ring || (target_valid && step==target_radius)));
    wire begin_op=state==ROT_BEGIN || state==ADD_BEGIN || state==RAY_RESET;
    wire run_bits=state==ROT_BITS || state==ADD_BITS;
    wire [2:0] command=state==RAY_RESET ? 3'd6 :
       (state==ADD_BEGIN || state==ADD_BITS) ? (axis ? 3'd5 : 3'd4) :
       rotate_up ? (second_op ? 3'd1 : 3'd0) : (second_op ? 3'd3 : 3'd2);
    minsky_serial_registers datapath(
       .clk(clk),.rst(rst),.begin_command(begin_op),.command(command),
       .step_enable(run_bits),.bit_index(bit_index),.c(c),.s(s),.x_acc(x_acc),.y_acc(y_acc));
    function [11:0] degree_next;
       input [11:0] value;input up;
       begin
          degree_next=value;
          if(up) begin
             if(value[3:0]!=9) degree_next[3:0]=value[3:0]+1'b1;
             else begin
                degree_next[3:0]=0;
                if(value[7:4]!=9) degree_next[7:4]=value[7:4]+1'b1;
                else begin degree_next[7:4]=0;degree_next[11:8]=value[11:8]+1'b1;end
             end
          end else begin
             if(value[3:0]!=0) degree_next[3:0]=value[3:0]-1'b1;
             else begin
                degree_next[3:0]=9;
                if(value[7:4]!=0) degree_next[7:4]=value[7:4]-1'b1;
                else begin degree_next[7:4]=9;degree_next[11:8]=value[11:8]-1'b1;end
             end
          end
       end
    endfunction
    function [11:0] ten_ahead;
       input [11:0] value;input up;
       begin
          ten_ahead=value;
          if(up) begin
             if(value[7:4]==9) begin ten_ahead[7:4]=0;ten_ahead[11:8]=value[11:8]+1'b1;end
             else ten_ahead[7:4]=value[7:4]+1'b1;
          end else begin
             if(value[7:4]==0) begin ten_ahead[7:4]=9;ten_ahead[11:8]=value[11:8]-1'b1;end
             else ten_ahead[7:4]=value[7:4]-1'b1;
          end
       end
    endfunction
    assign ready=ENABLE_READBACK && state==IDLE;
    assign bus_request=state==RMW && !pending && bus_ready;
    assign bus_read_op=transaction==3 || transaction==4;
    assign bus_data_op=bus_read_op || transaction==7;
    always @* begin
       case(transaction)
          0:bus_write_data={5'b10110,pixel_y[5:3]};
          1,5:bus_write_data={5'b00010,column[6:4]};
          2,6:bus_write_data={4'b0,column[3:0]};
          default:bus_write_data=erase ? bus_read_data & ~mask : bus_read_data | mask;
       endcase
    end
    always @(posedge clk) begin
       if(rst) begin
          state<=IDLE;original_angle<=0;ray_angle<=0;vector_angle<=0;phase<=16;
          rotate_up<=1;second_op<=0;axis<=0;micro_left<=0;bit_index<=0;
          erase<=0;flush_left<=0;target_radius<=6;target_valid<=0;step<=0;
          transaction<=0;pending<=0;dropped<=0;done<=0;
       end else begin
          done<=0;
          if(request && state!=IDLE && dropped!=255) dropped<=dropped+1'b1;
          case(state)
          IDLE:if(request && ENABLE_READBACK && angle_bcd<=12'h180) begin
             original_angle<=angle_bcd;
             target_radius<=radius<6 ? 6'd6 : radius;
             target_valid<=radius_valid && radius<=48;
             flush_left<=0;erase<=1;
             if(KEEP_END_BATCH && angle_bcd==12'h180 && !direction_up) begin
                ray_angle<=12'h170;flush_left<=10;
             end else if(KEEP_END_BATCH && angle_bcd==0 && direction_up) begin
                ray_angle<=0;flush_left<=10;
             end else if((direction_up && angle_bcd<=12'h170) || (!direction_up && angle_bcd>=12'h010))
                ray_angle<=ten_ahead(angle_bcd,direction_up);
             else begin ray_angle<=angle_bcd;erase<=0;end
             state<=ORIENT;
          end
          ORIENT:if(vector_angle==ray_angle) state<=RAY_RESET;
             else begin rotate_up<=vector_angle<ray_angle;state<=DEGREE;end
          DEGREE:begin
             // Dither 4/5 micro-rotations per logical degree: +15 mod32.
             if(rotate_up) begin
                phase<=phase+5'd15;micro_left<=phase>=17 ? 5 : 4;
             end else begin
                phase<=phase-5'd15;micro_left<=phase<15 ? 5 : 4;
             end
             second_op<=0;state<=ROT_BEGIN;
          end
          ROT_BEGIN:begin bit_index<=0;state<=ROT_BITS;end
          ROT_BITS:if(bit_index==18) begin
             if(!second_op) begin second_op<=1;state<=ROT_BEGIN;end
             else if(micro_left!=1) begin micro_left<=micro_left-1'b1;second_op<=0;state<=ROT_BEGIN;end
             else begin vector_angle<=degree_next(vector_angle,rotate_up);state<=ORIENT;end
          end else bit_index<=bit_index+1'b1;
          RAY_RESET:begin step<=0;state<=PIXEL;end
          PIXEL:if(selected) begin transaction<=0;pending<=0;state<=RMW;end
             else if(step==48) state<=AFTER_RAY;
             else begin axis<=0;state<=ADD_BEGIN;end
          ADD_BEGIN:begin bit_index<=0;state<=ADD_BITS;end
          ADD_BITS:if(bit_index==23) begin
             if(!axis) begin axis<=1;state<=ADD_BEGIN;end
             else begin step<=step+1'b1;state<=PIXEL;end
          end else bit_index<=bit_index+1'b1;
          RMW:begin
             if(bus_request) pending<=1;
             if(bus_done && pending) begin
                pending<=0;
                if(transaction==7) begin
                   if(step==48) state<=AFTER_RAY;
                   else begin axis<=0;state<=ADD_BEGIN;end
                end else transaction<=transaction+1'b1;
             end
          end
          AFTER_RAY:if(erase) begin
             if(flush_left!=0) begin
                ray_angle<=degree_next(ray_angle,1'b1);flush_left<=flush_left-1'b1;
             end else begin ray_angle<=original_angle;erase<=0;end
             state<=ORIENT;
          end else begin state<=IDLE;done<=1;end
          default:state<=IDLE;
          endcase
       end
    end
endmodule
