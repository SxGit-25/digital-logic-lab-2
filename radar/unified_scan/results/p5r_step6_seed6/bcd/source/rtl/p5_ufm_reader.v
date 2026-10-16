`timescale 1ns/1ps
// ALTUFM_NONE serial reader. No busy/rtpbusy/osc feedback is used.
// sequential=0 loads address; sequential=1 increments the UFM address once.
// First request after reset must be a non-sequential request.
module p5_ufm_reader #(
    parameter INIT_FILE = "background.mif",
    parameter SIM_FILE = "background.mem",
    parameter SIM_OUTPUT_DELAY_NS = 180
)(
    input wire clk,
    input wire rst,
    input wire request,
    input wire sequential,
    input wire [8:0] address,
    output wire busy,
    output reg done,
    output reg [15:0] value
);
    localparam IDLE=0, ALIGN=1, ADDR=2, ACCESS=3, LOAD=4, SHIFT=5;
    reg [2:0] state;
    reg [3:0] phase, bit_count;
    reg [8:0] addr_shift;
    reg arclk, arshft, drclk, drshft;
    wire serial_data;
    assign busy = state != IDLE;
`ifdef ALTERA_RESERVED_QIS
`define P5_UFM_HARDWARE
`elsif SYNTHESIS
`define P5_UFM_HARDWARE
`endif
`ifdef P5_UFM_HARDWARE
    altufm_none #(
        .width_ufm_address(9), .lpm_file(INIT_FILE),
        .port_arclkena("PORT_UNUSED"), .port_drclkena("PORT_UNUSED")
    ) flash (
        .arclk(arclk), .arclkena(1'b1), .ardin(addr_shift[8]), .arshft(arshft),
        .drclk(drclk), .drclkena(1'b1), .drdin(1'b0), .drshft(drshft),
        .erase(1'b0), .program(1'b0), .oscena(1'b0),
        .drdout(serial_data), .busy(), .osc(), .rtpbusy()
    );
`undef P5_UFM_HARDWARE
`else
    // Quartus 9.1 maxii_ufm ignores init_file contents in standalone RTL
    // simulation (requires 16 generated mem parameters). Use the exact same
    // 512-word image, with a deliberately conservative 180 ns output delay.
    reg [15:0] model_memory [0:511];
    reg [8:0] model_address = 0;
    reg [15:0] model_data = 0;
    initial $readmemh(SIM_FILE, model_memory);
    always @(posedge arclk)
        if (arshft) model_address <= {model_address[7:0], addr_shift[8]};
        else model_address <= model_address + 1'b1;
    always @(posedge drclk)
        if (!drshft) model_data <= #SIM_OUTPUT_DELAY_NS model_memory[model_address];
        else model_data <= #SIM_OUTPUT_DELAY_NS {model_data[14:0], 1'b0};
    assign serial_data = model_data[15];
`endif
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE; phase <= 0; bit_count <= 0;
            addr_shift <= 0; arclk <= 0; arshft <= 1;
            drclk <= 0; drshft <= 1; done <= 0; value <= 0;
        end else begin
            // Fixed phase, including between requests: /16 generated clocks.
            // High/low 160 ns; controls change at falling edge. Serial input
            // is sampled 300 ns after DRCLK's rising edge.
            phase <= phase + 1'b1;
            done <= 0;
            case (state)
                IDLE: if (request) begin
                    addr_shift <= address;
                    arshft <= !sequential;
                    bit_count <= sequential ? 4'd8 : 4'd0;
                    state <= ALIGN;
                end
                ALIGN: if (phase == 15) state <= ADDR;
                ADDR: begin
                    if (phase == 0) arclk <= 1;
                    if (phase == 8) begin
                        arclk <= 0;
                        addr_shift <= {addr_shift[7:0],1'b0};
                    end
                    if (phase == 15) begin
                        if (bit_count == 8) begin
                            bit_count <= 0; state <= ACCESS;
                        end else bit_count <= bit_count + 1'b1;
                    end
                end
                ACCESS: begin
                    if (phase == 8) drshft <= 0;
                    if (phase == 15) state <= LOAD;
                end
                LOAD: begin
                    if (phase == 0) drclk <= 1;
                    if (phase == 8) begin drclk <= 0; drshft <= 1; end
                    if (phase == 15) begin
                        value <= {value[14:0],serial_data}; state <= SHIFT;
                    end
                end
                SHIFT: begin
                    if (phase == 0) drclk <= 1;
                    if (phase == 8) drclk <= 0;
                    if (phase == 15) begin
                        value <= {value[14:0],serial_data};
                        if (bit_count == 14) begin done <= 1; state <= IDLE; end
                        else bit_count <= bit_count + 1'b1;
                    end
                end
                default: state <= IDLE;
            endcase
        end
    end
endmodule
