`timescale 1ns/1ps
// Experimental replacement for bridge/ray/LUT: one microsequencer drives a
// shared bit-serial ALU and the existing LCD bus. No request queue/backpressure.
// Busy requests are dropped and counted. Each accepted request rebuilds its
// first ray from the canonical zero vector; subsequent A/B and endpoint rays
// use exact forward/inverse degree microsteps. No absolute renderer angle tag.
module radar_minsky_draw_compact #(
    parameter ENABLE_READBACK=0,
    parameter KEEP_END_BATCH=1,
    parameter FRACTION_BITS=15,
    parameter ROT_SHIFT=7,
    parameter PHASE_BITS=6,
    parameter PHASE_ADD=15,
    parameter PHASE_INITIAL=63,
    parameter MICRO_BASE=2
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
      RAY_RESET=5,PIXEL=6,ADD_BEGIN=7,ADD_BITS=8,RMW=9,AFTER_RAY=10,VECTOR_RESET=11;
    reg [3:0] state;
    reg [7:0] degrees_left;
    reg return_up,end_same;
    // Input digits are the sole externally maintained scan angle. Conversion
    // occurs only at request acceptance; there is no multiplier or second scan.
    wire [7:0] tens_eight={1'b0,angle_bcd[7:4],3'b0};
    wire [7:0] tens_two={3'b0,angle_bcd[7:4],1'b0};
    wire [7:0] decimal_low=tens_eight+tens_two+{4'b0,angle_bcd[3:0]};
    wire [7:0] binary_angle=decimal_low+(angle_bcd[8] ? 8'd100 : 8'd0);
    wire ordinary_a=(direction_up && angle_bcd<=12'h170) ||
                    (!direction_up && angle_bcd>=12'h010);
    wire [7:0] first_a=binary_angle+(direction_up ? 8'd10 : 8'd246);
    reg [PHASE_BITS-1:0] phase;
    localparam [PHASE_BITS-1:0] PHASE_FORWARD=PHASE_ADD;
    localparam [PHASE_BITS-1:0] PHASE_BACKWARD=-PHASE_ADD;
    wire [PHASE_BITS:0] phase_sum={1'b0,phase}+
        {1'b0,(rotate_up ? PHASE_FORWARD : PHASE_BACKWARD)};
    reg rotate_up,second_op,axis;
    reg [2:0] micro_left;
    reg [4:0] bit_index;
    reg erase;
    reg [3:0] flush_left;
    reg [5:0] target_radius,step;
    reg target_valid;
    reg [2:0] transaction;
    reg pending;
    wire signed [FRACTION_BITS+1:0] c,s;
    wire signed [FRACTION_BITS+6:0] x_acc,y_acc;
    wire [6:0] column={~x_acc[FRACTION_BITS+6],x_acc[FRACTION_BITS+5:FRACTION_BITS]};
    wire [5:0] pixel_y=~y_acc[FRACTION_BITS+5:FRACTION_BITS];
    wire [7:0] mask=8'b1<<pixel_y[2:0];
    wire ring=step==16 || step==32 || step==48;
    wire selected=step>=6 && (erase ? !ring : (ring || (target_valid && step==target_radius)));
    wire begin_op=state==ROT_BEGIN || state==ADD_BEGIN || state==RAY_RESET || state==VECTOR_RESET;
    wire run_bits=state==ROT_BITS || state==ADD_BITS;
    wire [2:0] command=state==VECTOR_RESET ? 3'd7 : state==RAY_RESET ? 3'd6 :
       (state==ADD_BEGIN || state==ADD_BITS) ? (axis ? 3'd5 : 3'd4) :
       rotate_up ? (second_op ? 3'd1 : 3'd0) : (second_op ? 3'd3 : 3'd2);
    minsky_serial_registers #(.FRACTION_BITS(FRACTION_BITS),.ROT_SHIFT(ROT_SHIFT)) datapath(
       .clk(clk),.rst(rst),.begin_command(begin_op),.command(command),
       .step_enable(run_bits),.bit_index(bit_index),.c(c),.s(s),.x_acc(x_acc),.y_acc(y_acc));
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
          state<=IDLE;degrees_left<=0;return_up<=0;end_same<=0;phase<=PHASE_INITIAL;
          rotate_up<=1;second_op<=0;axis<=0;micro_left<=0;bit_index<=0;
          erase<=0;flush_left<=0;target_radius<=6;target_valid<=0;step<=0;
          transaction<=0;pending<=0;dropped<=0;done<=0;
       end else begin
          done<=0;
          if(request && state!=IDLE && dropped!=255) dropped<=dropped+1'b1;
          case(state)
          IDLE:if(request && ENABLE_READBACK && angle_bcd<=12'h180) begin
             return_up<=!direction_up;end_same<=0;
             phase<=PHASE_INITIAL;rotate_up<=1;
             target_radius<=radius<6 ? 6'd6 : radius;
             target_valid<=radius_valid && radius<=48;
             flush_left<=0;erase<=1;
             if(KEEP_END_BATCH && angle_bcd==12'h180 && !direction_up) begin
                degrees_left<=8'd170;flush_left<=10;end_same<=1;
             end else if(KEEP_END_BATCH && angle_bcd==0 && direction_up) begin
                degrees_left<=0;flush_left<=10;
             end else if(ordinary_a) degrees_left<=first_a;
             else begin degrees_left<=binary_angle;erase<=0;end
             state<=VECTOR_RESET;
          end
          VECTOR_RESET:state<=ORIENT;
          ORIENT:if(degrees_left==0) state<=RAY_RESET;
             else state<=DEGREE;
          DEGREE:begin
             // The same modular schedule is exactly reversible. The reverse
             // carry is the complement of addition by the negative residue.
             phase<=phase_sum[PHASE_BITS-1:0];
             micro_left<=MICRO_BASE+(phase_sum[PHASE_BITS] ^ !rotate_up);
             second_op<=0;state<=ROT_BEGIN;
          end
          ROT_BEGIN:begin bit_index<=0;state<=ROT_BITS;end
          ROT_BITS:if(bit_index==FRACTION_BITS+1) begin
             if(!second_op) begin second_op<=1;state<=ROT_BEGIN;end
             else if(micro_left!=1) begin micro_left<=micro_left-1'b1;second_op<=0;state<=ROT_BEGIN;end
             else begin degrees_left<=degrees_left-1'b1;state<=ORIENT;end
          end else bit_index<=bit_index+1'b1;
          RAY_RESET:begin step<=0;state<=PIXEL;end
          PIXEL:if(selected) begin transaction<=0;pending<=0;state<=RMW;end
             else if(step==48) state<=AFTER_RAY;
             else begin axis<=0;state<=ADD_BEGIN;end
          ADD_BEGIN:begin bit_index<=0;state<=ADD_BITS;end
          ADD_BITS:if(bit_index==FRACTION_BITS+6) begin
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
                degrees_left<=1;rotate_up<=1;flush_left<=flush_left-1'b1;
             end else begin degrees_left<=end_same ? 8'd0 : 8'd10;rotate_up<=return_up;erase<=0;end
             state<=ORIENT;
          end else begin state<=IDLE;done<=1;end
          default:state<=IDLE;
          endcase
       end
    end
endmodule
