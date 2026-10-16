`timescale 1ns/1ps
// One shared sin lookup, sequential sin/cos requests. Q1.F coefficients;
// unsigned Q6.F magnitudes, round-to-nearest only at the pixel output.
module ray_engine #(
    parameter USE_UFM=0,
    parameter MIRROR_X=0,
    parameter [5:0] MIN_RADIUS=6,
    parameter FRACTION_BITS=8,
    parameter SERIAL_ACCUMULATE=0
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
    localparam IDLE=0,SIN_REQ=1,SIN_WAIT=2,COS_REQ=3,COS_WAIT=4,WALK=5,ADD_BITS=6;
    reg [2:0] state;
    reg [6:0] theta;
    reg negative_x;
    reg [FRACTION_BITS:0] sin_value;
    reg [FRACTION_BITS+5:0] x_acc,y_acc;
    reg [5:0] count;
    reg [3:0] serial_bit;
    reg x_carry,y_carry;
    wire lut_done;
    wire [FRACTION_BITS:0] lut_value;
    wire [6:0] lut_address=state==COS_REQ ? 7'd90-theta : theta;
    lcd_sin_lut #(.USE_UFM(USE_UFM),.FRACTION_BITS(FRACTION_BITS)) lut(
        .clk(clk),.rst(rst),.request(state==SIN_REQ || state==COS_REQ),
        .address(lut_address),.done(lut_done),.value(lut_value));
    localparam [FRACTION_BITS+5:0] ROUND_HALF = 1 << (FRACTION_BITS-1);
    // Bias each accumulator once, rather than adding a rounding constant at
    // every pixel. LUT output holds cosine throughout WALK, so no copy is needed.
    wire [5:0] dx=x_acc[FRACTION_BITS+5:FRACTION_BITS];
    wire [5:0] dy=y_acc[FRACTION_BITS+5:FRACTION_BITS];
    assign x=negative_x ? 7'd64-{1'b0,dx} : 7'd64+{1'b0,dx};
    assign y=6'd63-dy;
    assign step=count;
    // Optional bit-serial adder reuses one full-adder per coordinate.
    // The accumulator rotates through all bits before exposing the next pixel.
    wire x_coefficient_bit=serial_bit<=FRACTION_BITS ? lut_value[serial_bit] : 1'b0;
    wire y_coefficient_bit=serial_bit<=FRACTION_BITS ? sin_value[serial_bit] : 1'b0;
    wire [1:0] x_serial_sum={1'b0,x_acc[0]}+{1'b0,x_coefficient_bit}+x_carry;
    wire [1:0] y_serial_sum={1'b0,y_acc[0]}+{1'b0,y_coefficient_bit}+y_carry;
    assign busy=state!=IDLE;
    assign pixel_valid=state==WALK && count>=MIN_RADIUS;
    always @(posedge clk) begin
        if(rst) begin
            state<=IDLE;theta<=0;negative_x<=0;sin_value<=0;
            x_acc<=0;y_acc<=0;count<=0;done<=0;
            serial_bit<=0;x_carry<=0;y_carry<=0;
        end else begin
            done<=0;
            case(state)
            IDLE: if(start && angle<=180) begin
                theta<=angle>90 ? 8'd180-angle : angle;
                negative_x<=(angle>90) ^ (MIRROR_X!=0);
                x_acc<=ROUND_HALF;y_acc<=ROUND_HALF;count<=0;state<=SIN_REQ;
            end
            SIN_REQ:state<=SIN_WAIT;
            SIN_WAIT:if(lut_done) begin sin_value<=lut_value;state<=COS_REQ;end
            COS_REQ:state<=COS_WAIT;
            COS_WAIT:if(lut_done) begin state<=WALK;end
            WALK:if(count<MIN_RADIUS || pixel_ready) begin
                if(count==48) begin state<=IDLE;done<=1;end
                else if(SERIAL_ACCUMULATE) begin
                    serial_bit<=0;x_carry<=0;y_carry<=0;state<=ADD_BITS;
                end else begin
                    count<=count+1'b1;
                    x_acc<=x_acc+{5'b0,lut_value};
                    y_acc<=y_acc+{5'b0,sin_value};
                end
            end
            ADD_BITS:begin
                x_acc<={x_serial_sum[0],x_acc[FRACTION_BITS+5:1]};
                y_acc<={y_serial_sum[0],y_acc[FRACTION_BITS+5:1]};
                x_carry<=x_serial_sum[1];y_carry<=y_serial_sum[1];
                if(serial_bit==FRACTION_BITS+5) begin
                    count<=count+1'b1;state<=WALK;
                end else serial_bit<=serial_bit+1'b1;
            end
            default:state<=IDLE;
            endcase
        end
    end
endmodule
