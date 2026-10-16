`timescale 1ns/1ps
// Experimental replacement for bridge/ray/LUT: one microsequencer drives a
// shared bit-serial ALU and the existing LCD bus. No request queue/backpressure.
// Busy requests are dropped and counted. Each accepted request rebuilds its
// first ray from the canonical zero vector; subsequent A/B and endpoint rays
// use exact forward/inverse degree microsteps. No absolute renderer angle tag.
module radar_lcd_micro #(
    parameter ENABLE_READBACK=0,
    parameter P5_FIXES=0,
    parameter [7:0] CONTRAST=8'h1c,
    parameter KEEP_END_BATCH=1,
    parameter FRACTION_BITS=15,
    parameter ROT_SHIFT=7,
    parameter PHASE_BITS=6,
    parameter PHASE_ADD=15,
    parameter PHASE_INITIAL=63,
    parameter MICRO_BASE=2
)(
    input wire clk,rst,request,tick_ms,
    input wire continuous_mode,
    output reg initialized,
    output wire lcd_rst_n,
    input wire [11:0] angle_bcd,
    input wire direction_up,
    input wire [5:0] radius,
    input wire radius_valid,
    output wire ready,
    output reg done,
    (* preserve, noprune *) output reg [7:0] dropped,
    output wire bus_request,bus_read_op,bus_data_op,
    output reg [7:0] bus_write_data,
    input wire bus_ready,bus_done,
    input wire [7:0] bus_read_data
);
    localparam IDLE=0,ORIENT=1,DEGREE=2,ROT_BEGIN=3,ROT_BITS=4,
      RAY_RESET=5,PIXEL=6,ADD_BEGIN=7,ADD_BITS=8,RMW=9,AFTER_RAY=10,VECTOR_RESET=11,INIT_RESET=12,INIT_WAIT=13,INIT_SEND=14,INIT_ACK=15,CONVERT_ANGLE=16,ANGLE_OFFSET=17;
    reg [4:0] state;
    reg [7:0] position_count;
    wire [7:0] degrees_left=position_count;
    wire [5:0] step=position_count[5:0];
    reg return_up,end_same;
    // Input digits are the sole externally maintained scan angle. Conversion
    // occurs only at request acceptance; there is no multiplier or second scan.
    reg latest_direction,latest_valid,return_ten;
    reg [11:0] latest_angle;
    reg [5:0] latest_radius;
    wire queued=P5_FIXES && pending;
    wire [11:0] draw_angle=request ? angle_bcd : latest_angle;
    wire draw_direction=request ? direction_up : latest_direction;
    wire [5:0] draw_radius=request ? radius : latest_radius;
    wire draw_valid=request ? radius_valid : latest_valid;
    wire basic_zero=P5_FIXES && !continuous_mode;
    wire ordinary_a=basic_zero || (draw_direction && draw_angle<=12'h170) ||
                    (!draw_direction && draw_angle>=12'h010);
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
    reg [5:0] target_radius;
    reg target_valid;
    wire [2:0] transaction=bit_index[2:0];
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
    minsky_serial_registers #(.FRACTION_BITS(FRACTION_BITS),.ROT_SHIFT(ROT_SHIFT),.RESET_DATA(0)) datapath(
       .clk(clk),.rst(rst),.begin_command(begin_op),.command(command),
       .step_enable(run_bits),.bit_index(bit_index),.c(c),.s(s),.x_acc(x_acc),.y_acc(y_acc));
    wire accept=(request || queued) && ENABLE_READBACK && state==IDLE && draw_angle<=12'h180;
    wire endpoint_high=KEEP_END_BATCH && draw_angle==12'h180 && !draw_direction;
    wire endpoint_low=KEEP_END_BATCH && draw_angle==0 && draw_direction;
    wire [7:0] initial_degrees=endpoint_high ? 8'd170 : endpoint_low ? 8'd0 :
        {4'b0,draw_angle[3:0]}+(draw_angle[8] ? 8'd100 : 8'd0);
    wire degree_done=state==ROT_BITS && bit_index==FRACTION_BITS+1 && second_op && micro_left==1;
    wire after_erase=state==AFTER_RAY && erase;
    wire [4:0] last_bit=state==ROT_BITS ? FRACTION_BITS+1 : FRACTION_BITS+6;
    wire ray_step_done=state==ADD_BITS && bit_index==FRACTION_BITS+6 && axis;
    wire init_delay=state==INIT_RESET || state==INIT_WAIT;
    wire init_clear=state==INIT_SEND && bus_done && flush_left==11 && position_count!=0;
    wire position_decrement=degree_done || init_delay || init_clear;
    wire [7:0] position_delta=state==CONVERT_ANGLE ? 8'd10 : state==ANGLE_OFFSET ? (return_up ? 8'd246 : 8'd10) : position_decrement ? 8'hff : 8'd1;
    wire [7:0] position_next=position_count+position_delta;
    // Orientation and radial progress never coexist. Their sole count register
    // is loaded before each mode and shares one increment/decrement chain.
    always @(posedge clk) begin
        if(rst) position_count<=1;
        else if((state==INIT_RESET || state==INIT_WAIT) && tick_ms) begin
            if(position_count!=0) position_count<=position_next;
            else if(state==INIT_RESET) position_count<=20;
        end else if(state==INIT_SEND && bus_done) begin
            if(flush_left==3) position_count<=20;
            else if(flush_left==10) position_count<=131;
            else if(flush_left==11 && position_count!=0) position_count<=position_next;
        end else if(accept) position_count<=initial_degrees;
        else if(degree_done || ray_step_done || (state==CONVERT_ANGLE && bit_index!=0) || (state==ANGLE_OFFSET && erase && flush_left==0 && !basic_zero)) position_count<=position_next;
        else if(after_erase) position_count<=flush_left!=0 ? 8'd1 : P5_FIXES ? (return_ten ? 8'd10 : 8'd0) : end_same ? 8'd0 : 8'd10;
        else if(state==RAY_RESET) position_count<=0;
    end
    wire start_pixel=state==PIXEL && selected;
    wire bus_advance=state==RMW && bus_done && transaction!=7;
    // RMW transactions and serial arithmetic likewise share five count bits.
    always @(posedge clk) begin
        if(accept) bit_index<=endpoint_high || endpoint_low ? 5'd0 : {1'b0,draw_angle[7:4]};
        else if(state==ROT_BEGIN || state==ADD_BEGIN || start_pixel) bit_index<=0;
        else if((state==CONVERT_ANGLE && bit_index!=0) || (run_bits && bit_index!=last_bit) || bus_advance) bit_index<=bit_index+(state==CONVERT_ANGLE ? 5'd31 : 5'd1);
    end
    always @(posedge clk) begin
        if(accept) phase<=PHASE_INITIAL;
        else if(state==DEGREE) phase<=phase_sum[PHASE_BITS-1:0];
    end
    assign ready=ENABLE_READBACK && initialized && state==IDLE;
    assign lcd_rst_n=state!=INIT_RESET;
    assign bus_request=(state==RMW || state==INIT_SEND) && bus_ready && !bus_done;
    assign bus_read_op=initialized && (transaction==3 || transaction==4);
    assign bus_data_op=initialized ? (bus_read_op || transaction==7) : flush_left==11;
    always @* begin
       if(!initialized) begin
          case(flush_left)
             0:bus_write_data=8'ha2;1:bus_write_data=8'ha0;2:bus_write_data=8'hc8;
             3:bus_write_data=8'h2f;4:bus_write_data=8'h24;5:bus_write_data=8'h81;
             6:bus_write_data=CONTRAST;7:bus_write_data=8'h40;
             8:bus_write_data={5'b10110,micro_left};
             9:bus_write_data=8'h10;10:bus_write_data=0;
             12:bus_write_data=8'haf;default:bus_write_data=0;
          endcase
       end else case(transaction)
          0:bus_write_data={5'b10110,pixel_y[5:3]};
          1,5:bus_write_data={5'b00010,column[6:4]};
          2,6:bus_write_data={4'b0,column[3:0]};
          default:bus_write_data=erase ? bus_read_data & ~mask : bus_read_data | mask;
       endcase
    end
    always @(posedge clk) begin
       if(rst) begin
          state<=INIT_RESET;initialized<=0;return_up<=0;end_same<=0;
          rotate_up<=1;second_op<=0;axis<=0;micro_left<=0;
          erase<=0;flush_left<=0;target_radius<=6;target_valid<=0;
          pending<=0;dropped<=0;done<=0;return_ten<=0;
       end else begin
          done<=0;
          if(P5_FIXES) begin
             if(request && ENABLE_READBACK && initialized) begin
                latest_angle<=angle_bcd;latest_direction<=direction_up;
                latest_radius<=radius;latest_valid<=radius_valid;
                pending<=!accept;
                if(pending && !accept && dropped!=255) dropped<=dropped+1'b1;
             end else if(accept) pending<=0;
          end else if(request && state!=IDLE && dropped!=255) dropped<=dropped+1'b1;
          case(state)
          INIT_RESET:if(tick_ms && position_count==0) state<=INIT_WAIT;
          INIT_WAIT:if(tick_ms && position_count==0) state<=INIT_SEND;
          INIT_SEND:if(bus_done) begin
             if(flush_left==3) begin flush_left<=4;state<=INIT_WAIT;end
             else if(flush_left==12) begin initialized<=1;state<=IDLE;end
             else if(flush_left==11) begin
                if(position_count!=0) state<=INIT_SEND;
                else if(micro_left==7) begin flush_left<=12;state<=INIT_SEND;end
                else begin micro_left<=micro_left+1'b1;flush_left<=8;state<=INIT_SEND;end
             end else begin flush_left<=flush_left+1'b1;state<=INIT_SEND;end
          end
          IDLE:if(accept) begin
             return_up<=!draw_direction;end_same<=0;
             return_ten<=endpoint_low || (!endpoint_high && !basic_zero);
             rotate_up<=1;
             target_radius<=draw_radius<6 ? 6'd6 : draw_radius;
             target_valid<=draw_valid && draw_radius<=48;
             flush_left<=0;erase<=1;
             if(endpoint_high) begin
                flush_left<=10;end_same<=1;
             end else if(endpoint_low) begin
                flush_left<=10;
             end else if(!ordinary_a) erase<=0;
             state<=CONVERT_ANGLE;
          end
          CONVERT_ANGLE:if(bit_index==0) state<=ANGLE_OFFSET;
          ANGLE_OFFSET:state<=VECTOR_RESET;
          VECTOR_RESET:state<=ORIENT;
          ORIENT:if(degrees_left==0) state<=RAY_RESET;
             else state<=DEGREE;
          DEGREE:begin
             // The same modular schedule is exactly reversible. The reverse
             // carry is the complement of addition by the negative residue.
             micro_left<=MICRO_BASE+(phase_sum[PHASE_BITS] ^ !rotate_up);
             second_op<=0;state<=ROT_BEGIN;
          end
          ROT_BEGIN:state<=ROT_BITS;
          ROT_BITS:if(bit_index==FRACTION_BITS+1) begin
             if(!second_op) begin second_op<=1;state<=ROT_BEGIN;end
             else if(micro_left!=1) begin micro_left<=micro_left-1'b1;second_op<=0;state<=ROT_BEGIN;end
             else state<=ORIENT;
          end
          RAY_RESET:state<=PIXEL;
          PIXEL:if(selected) begin if(!P5_FIXES) pending<=0;state<=RMW;end
             else if(step==48) state<=AFTER_RAY;
             else begin axis<=0;state<=ADD_BEGIN;end
          ADD_BEGIN:state<=ADD_BITS;
          ADD_BITS:if(bit_index==FRACTION_BITS+6) begin
             if(!axis) begin axis<=1;state<=ADD_BEGIN;end
             else state<=PIXEL;
          end
          RMW:begin
             if(bus_done) begin
                if(!P5_FIXES) pending<=0;
                if(transaction==7) begin
                   if(step==48) state<=AFTER_RAY;
                   else begin axis<=0;state<=ADD_BEGIN;end
                end
             end
          end
          AFTER_RAY:if(erase) begin
             if(flush_left!=0) begin
                rotate_up<=1;flush_left<=flush_left-1'b1;
             end else begin rotate_up<=return_up;erase<=0;end
             state<=ORIENT;
          end else begin state<=IDLE;done<=1;end
          default:state<=IDLE;
          endcase
       end
    end
endmodule
