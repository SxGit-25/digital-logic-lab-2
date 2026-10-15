`timescale 1ns/1ps
// One shared sin lookup, sequential sin/cos requests. Q1.8 coefficients;
// unsigned Q6.8 magnitudes, round-to-nearest only at the pixel output.
module ray_engine #(
    parameter USE_UFM=0,
    parameter MIRROR_X=0,
    parameter [5:0] MIN_RADIUS=6
)(
    input wire clk, rst, start,
    input wire [7:0] angle,
    output wire busy,
    output reg done,
    output wire pixel_valid,
    input wire pixel_ready,
    output wire [5:0] step,
    output wire [6:0] x,
    output wire [5:0] y
);
    localparam IDLE=0,SIN_REQ=1,SIN_WAIT=2,COS_REQ=3,COS_WAIT=4,WALK=5;
    reg [2:0] state;
    reg [6:0] theta;
    reg negative_x;
    reg [8:0] sin_value,cos_value;
    reg [13:0] x_acc,y_acc;
    reg [5:0] count;
    wire lut_done;
    wire [8:0] lut_value;
    wire [6:0] lut_address=state==COS_REQ ? 7'd90-theta : theta;
    lcd_sin_lut #(.USE_UFM(USE_UFM)) lut(
        .clk(clk),.rst(rst),.request(state==SIN_REQ || state==COS_REQ),
        .address(lut_address),.done(lut_done),.value(lut_value));
    wire [13:0] rounded_x=x_acc+14'd128;
    wire [13:0] rounded_y=y_acc+14'd128;
    wire [5:0] dx=rounded_x[13:8];
    wire [5:0] dy=rounded_y[13:8];
    assign x=negative_x ? 7'd64-{1'b0,dx} : 7'd64+{1'b0,dx};
    assign y=6'd63-dy;
    assign step=count;
    assign busy=state!=IDLE;
    assign pixel_valid=state==WALK && count>=MIN_RADIUS;
    always @(posedge clk) begin
        if(rst) begin
            state<=IDLE;theta<=0;negative_x<=0;sin_value<=0;cos_value<=0;
            x_acc<=0;y_acc<=0;count<=0;done<=0;
        end else begin
            done<=0;
            case(state)
            IDLE: if(start && angle<=180) begin
                theta<=angle>90 ? 8'd180-angle : angle;
                negative_x<=(angle>90) ^ (MIRROR_X!=0);
                x_acc<=0;y_acc<=0;count<=0;state<=SIN_REQ;
            end
            SIN_REQ:state<=SIN_WAIT;
            SIN_WAIT:if(lut_done) begin sin_value<=lut_value;state<=COS_REQ;end
            COS_REQ:state<=COS_WAIT;
            COS_WAIT:if(lut_done) begin cos_value<=lut_value;state<=WALK;end
            WALK:if(count<MIN_RADIUS || pixel_ready) begin
                if(count==48) begin state<=IDLE;done<=1;end
                else begin
                    count<=count+1'b1;
                    x_acc<=x_acc+{5'b0,cos_value};
                    y_acc<=y_acc+{5'b0,sin_value};
                end
            end
            default:state<=IDLE;
            endcase
        end
    end
endmodule
