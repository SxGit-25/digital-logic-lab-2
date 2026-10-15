`timescale 1ns/1ps
// A: erase the ray 10 degrees ahead (excluding radial steps 16/32/48).
// B: set current ray's ring points and one valid target. No history RAM.
// Each pixel uses ordinary reads: reset column after dummy+real reads,
// since those reads advance the LCD address. Never write to that advanced column.
module radar_lcd_ctrl #(
    parameter USE_UFM=0,
    parameter MIRROR_X=0
)(
    input wire clk,rst,request,
    input wire [7:0] angle,
    input wire direction_up,
    input wire [5:0] radius,
    input wire radius_valid,
    output wire ready,
    output reg done,
    output wire bus_request,
    output wire bus_read_op,bus_data_op,
    output wire [7:0] bus_write_data,
    input wire bus_ready,bus_done,
    input wire [7:0] bus_read_data
);
    localparam IDLE=0,START_A=1,START_B=2,RUN=3,RMW=4,WAIT_RAY=5;
    reg [2:0] state;
    reg erase;
    reg [7:0] current_angle,ray_angle;
    reg [5:0] target_radius;
    reg target_valid;
    wire ray_busy,ray_done,pixel_valid;
    wire [5:0] pixel_step;
    wire [6:0] pixel_x;
    wire [5:0] pixel_y;
    wire ring_point=pixel_step==16 || pixel_step==32 || pixel_step==48;
    wire selected=erase ? !ring_point : (ring_point || (target_valid && pixel_step==target_radius));
    wire pixel_ready=(state==RUN && !selected) || state==WAIT_RAY;
    ray_engine #(.USE_UFM(USE_UFM),.MIRROR_X(MIRROR_X)) ray(
        .clk(clk),.rst(rst),.start(state==START_A || state==START_B),.angle(ray_angle),
        .busy(ray_busy),.done(ray_done),.pixel_valid(pixel_valid),.pixel_ready(pixel_ready),
        .step(pixel_step),.x(pixel_x),.y(pixel_y));
    reg [2:0] page;
    reg [6:0] column;
    reg [7:0] mask,new_byte;
    reg [3:0] transaction;
    reg pending;
    // 0:page,1:column high,2:column low,3:dummy,4:read,
    // 5:restore column high,6:restore column low,7:modified data.
    assign ready=state==IDLE;
    assign bus_request=state==RMW && bus_ready && !pending;
    assign bus_read_op=transaction==3 || transaction==4;
    assign bus_data_op=transaction==3 || transaction==4 || transaction==7;
    reg [7:0] command;
    always @* begin
        case(transaction)
        0:command=8'hb0|{5'b0,page};
        1,5:command=8'h10|{5'b0,column[6:4]};
        2,6:command={4'b0,column[3:0]};
        default:command=new_byte;
        endcase
    end
    assign bus_write_data=command;
    always @(posedge clk) begin
        if(rst) begin
            state<=IDLE;erase<=0;current_angle<=0;ray_angle<=0;
            target_radius<=0;target_valid<=0;done<=0;
            page<=0;column<=0;mask<=0;new_byte<=0;transaction<=0;pending<=0;
        end else begin
            done<=0;
            case(state)
            IDLE:if(request && angle<=180) begin
                current_angle<=angle;target_radius<=radius;
                target_valid<=radius_valid && radius>=4 && radius<=48;
                if((direction_up && angle<=170) || (!direction_up && angle>=10)) begin
                    ray_angle<=direction_up ? angle+8'd10 : angle-8'd10;
                    erase<=1;state<=START_A;
                end else begin ray_angle<=angle;erase<=0;state<=START_B;end
            end
            START_A,START_B:state<=RUN;
            RUN:begin
                if(pixel_valid && selected) begin
                    page<=pixel_y[5:3];column<=pixel_x;
                    mask<=8'b1<<pixel_y[2:0];transaction<=0;pending<=0;state<=RMW;
                end
                if(ray_done) begin
                    if(erase) begin erase<=0;ray_angle<=current_angle;state<=START_B;end
                    else begin state<=IDLE;done<=1;end
                end
            end
            RMW:begin
                if(bus_request) pending<=1;
                if(bus_done && pending) begin
                    pending<=0;
                    if(transaction==4) new_byte<=erase ? bus_read_data & ~mask : bus_read_data | mask;
                    if(transaction==7) state<=WAIT_RAY;
                    else transaction<=transaction+1'b1;
                end
            end
            // Consume exactly the pixel held stable during all eight bus transactions.
            WAIT_RAY:state<=RUN;
            default:state<=IDLE;
            endcase
        end
    end
endmodule
