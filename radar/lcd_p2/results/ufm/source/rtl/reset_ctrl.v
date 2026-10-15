`timescale 1ns/1ps

// MAX II registers support a defined power-up value.  Quartus must preserve
// this initializer; check the Power-Up Level column after compilation.
module reset_ctrl #(
    parameter integer RESET_CYCLES = 16
) (
    input  wire clk,
    output wire rst
);
    reg [RESET_CYCLES-1:0] reset_pipe = {RESET_CYCLES{1'b1}};

    always @(posedge clk)
        reset_pipe <= {reset_pipe[RESET_CYCLES-2:0], 1'b0};

    assign rst = reset_pipe[RESET_CYCLES-1];
endmodule
