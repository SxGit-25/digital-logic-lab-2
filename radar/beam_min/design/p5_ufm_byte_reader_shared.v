`timescale 1ns/1ps
// 8-bit ALTUFM_NONE reader, with shared 9-bit address/data shift storage.
// operation 00=random address, 01=increment UFM address, 10=continue low
// byte after a high-byte read. operation 11 is reserved (acts as continue).
// low_byte selects random/increment byte; continuation always returns low.
// Outputs are valid after done, until the next accepted request.
module p5_ufm_byte_reader #(
    parameter INIT_FILE="background.mif",
    parameter SIM_FILE="background.mem",
    parameter SIM_OUTPUT_DELAY_NS=180
)(
    input wire clk,rst,request,
    input wire [1:0] operation,
    input wire [8:0] address,
    input wire low_byte,
    output wire busy,
    output reg done,
    output wire [7:0] value
);
    localparam IDLE=0,ALIGN=1,ADDR=2,ACCESS=3,LOAD=4,SHIFT=5,CONT_ALIGN=6;
    reg [2:0] state;
    reg [3:0] phase,bit_count;
    reg [8:0] work;
    wire [8:0] addr_shift=work;
    reg arclk,arshft,drclk,drshft,active_low;
    wire serial_data;
    assign busy=state!=IDLE;
    assign value=work[7:0];
`ifdef ALTERA_RESERVED_QIS
`define P5_BYTE_UFM_HARDWARE
`elsif SYNTHESIS
`define P5_BYTE_UFM_HARDWARE
`endif
`ifdef P5_BYTE_UFM_HARDWARE
    altufm_none #(.width_ufm_address(9),.lpm_file(INIT_FILE),
        .port_arclkena("PORT_UNUSED"),.port_drclkena("PORT_UNUSED")) flash(
        .arclk(arclk),.arclkena(1'b1),.ardin(work[8]),.arshft(arshft),
        .drclk(drclk),.drclkena(1'b1),.drdin(1'b0),.drshft(drshft),
        .erase(1'b0),.program(1'b0),.oscena(1'b0),
        .drdout(serial_data),.busy(),.osc(),.rtpbusy());
`undef P5_BYTE_UFM_HARDWARE
`else
    // Same 512x16 image as hardware MIF; only a serial one-bit data path
    // is exposed. Extra settling delay is a stress model, not a tDCO claim.
    reg [15:0] model_memory[0:511];
    reg [8:0] model_address=0;
    reg [15:0] model_data=0;
    initial $readmemh(SIM_FILE,model_memory);
    always @(posedge arclk)
        if(arshft)model_address<={model_address[7:0],work[8]};
        else model_address<=model_address+1'b1;
    always @(posedge drclk)
        if(!drshft)model_data<=#SIM_OUTPUT_DELAY_NS model_memory[model_address];
        else model_data<=#SIM_OUTPUT_DELAY_NS {model_data[14:0],1'b0};
    assign serial_data=model_data[15];
`endif
    always @(posedge clk or posedge rst)begin
        if(rst)begin
            state<=IDLE;phase<=0;bit_count<=0;work<=0;
            arclk<=0;arshft<=1;drclk<=0;drshft<=1;active_low<=0;done<=0;
        end else begin
            phase<=phase+1'b1;
            done<=0;
            case(state)
                IDLE:if(request)begin
                    work<=address;
                    arshft<=!operation[0];
                    active_low<=low_byte || operation[1];
                    bit_count<=operation[1] ? 4'd7 : operation[0] ? 4'd8 : 4'd0;
                    state<=operation[1] ? CONT_ALIGN : ALIGN;
                end
                ALIGN:if(phase==15)state<=ADDR;
                CONT_ALIGN:if(phase==15)state<=SHIFT;
                ADDR:begin
                    if(phase==0)arclk<=1;
                    if(phase==8)begin arclk<=0;work<={work[7:0],1'b0};end
                    if(phase==15)begin
                        if(bit_count==8)begin bit_count<=0;state<=ACCESS;end
                        else bit_count<=bit_count+1'b1;
                    end
                end
                ACCESS:begin
                    if(phase==8)drshft<=0;
                    if(phase==15)state<=LOAD;
                end
                LOAD:begin
                    if(phase==0)drclk<=1;
                    if(phase==8)begin drclk<=0;drshft<=1;end
                    if(phase==15)begin work<={work[7:0],serial_data};state<=SHIFT;end
                end
                SHIFT:begin
                    if(phase==0)drclk<=1;
                    if(phase==8)drclk<=0;
                    if(phase==15)begin
                        work<={work[7:0],serial_data};
                        if(bit_count==(active_low ? 4'd14 : 4'd6))begin done<=1;state<=IDLE;end
                        else bit_count<=bit_count+1'b1;
                    end
                end
                default:state<=IDLE;
            endcase
        end
    end
endmodule
